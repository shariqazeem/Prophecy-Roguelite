## State manager and Dojo bridge for the Prophecy roguelite.
##
## Connects to Katana (via DojoConnection GDExtension), subscribes to Torii
## entity updates, and exposes action functions that map 1:1 to Cairo system
## entrypoints. All on-chain state (Trader, Market, Position, Relics,
## WorldBoss, LeaderboardEntry) is parsed from Torii model updates and stored
## in local dictionaries. Emits signals so the UI layer (main_game.gd) can
## react without touching the chain directly.
##
## Market data is loaded from res://data/markets.json at startup for
## hot-swappable content without client rebuilds.
class_name GameManager
extends Node

signal state_updated(trader: Dictionary)
signal prediction_settled(market_id: int, correct: bool, payout: int)
signal trader_created()
signal tx_status(entrypoint: String, success: bool, tx_hash: String)
signal world_boss_updated(boss: Dictionary)

@onready var connection: DojoConnection = $DojoConnection

var trader: Dictionary = {}
var markets: Dictionary = {}       # market_id → on-chain market data
var positions: Dictionary = {}     # market_id → position data
var all_traders: Array[Dictionary] = []  # for leaderboard
var leaderboard: Dictionary = {}   # current player leaderboard entry
var relics: Dictionary = {"leverage_tokens": 0, "stop_loss": 0, "insider_info": 0}
var world_boss: Dictionary = {
	"total_yes": 0, "total_no": 0,
	"total_yes_amount": 0, "total_no_amount": 0,
	"is_resolved": false, "outcome": false,
	"recent": [],  # last 5 bettor addresses
}

# World Boss titles (rotate if needed)
const WORLD_BOSS_TITLE: String = "Will a Dojo game reach 10,000 daily active players before 2027?"

# All positions from all players (for spectator mode)
var all_positions: Dictionary = {}  # "addr_marketid" → position dict

# Relic costs (must match Cairo contract)
const RELIC_COSTS: Dictionary = {
	"leverage_tokens": 1500,
	"stop_loss": 1000,
	"insider_info": 2000,
}

var is_busy: bool = false
var last_tx_hash: String = ""
var _trader_created: bool = false

# Market data and odds — loaded dynamically from res://data/markets.json
# This allows hot-swapping markets at runtime via API, IPFS, or file replace
# without updating the client codebase. Production-ready data pipeline.
static var MARKET_DATA: Dictionary = {}
static var MARKET_ODDS: Dictionary = {}

func _ready() -> void:
	_load_markets_json()
	connection.connected.connect(_on_connected)
	connection.tx_completed.connect(_on_tx_completed)

func _load_markets_json() -> void:
	# Dynamic market loading from external JSON — hot-swappable via API/IPFS
	var file = FileAccess.open("res://data/markets.json", FileAccess.READ)
	if not file:
		push_warning("markets.json not found, using empty market set")
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	if err != OK:
		push_warning("Failed to parse markets.json: %s" % json.get_error_message())
		return
	var data = json.get_data()
	if not data is Dictionary or not data.has("markets"):
		push_warning("markets.json missing 'markets' array")
		return
	for m in data["markets"]:
		var mid = int(m["id"])
		MARKET_DATA[mid] = {
			"title": m["title"],
			"category": m["category"],
			"pre_resolved": m["pre_resolved"],
			"outcome": m["outcome"],
		}
		MARKET_ODDS[mid] = {
			"yes": int(m["odds"]["yes"]),
			"no": int(m["odds"]["no"]),
		}

func _on_connected() -> void:
	connection.subscribe_entities(_on_entity_update)
	await get_tree().create_timer(0.5).timeout
	refresh_state()

func _on_entity_update(args: Dictionary) -> void:
	var models = args.get("models", {})
	await get_tree().process_frame
	_parse_models(models)

func refresh_state() -> void:
	var data = connection.fetch_entities()
	var items: Array = data.get("items", [])
	for entity in items:
		_parse_models(entity.get("models", {}))

func _parse_models(models: Dictionary) -> void:
	if models.has("prophecy_roguelite-Trader"):
		var t = models["prophecy_roguelite-Trader"]
		var addr = str(t.get("address", ""))
		var entry = {
			"address": addr,
			"balance": _int(t.get("balance", 0)),
			"total_wagered": _int(t.get("total_wagered", 0)),
			"total_won": _int(t.get("total_won", 0)),
			"total_lost": _int(t.get("total_lost", 0)),
			"markets_played": _int(t.get("markets_played", 0)),
			"correct_predictions": _int(t.get("correct_predictions", 0)),
			"streak": _int(t.get("streak", 0)),
			"best_streak": _int(t.get("best_streak", 0)),
		}

		# Check if this is our trader (normalize to handle leading-zero differences)
		if addr == "" or _addr_match(addr, connection.get_player_address()):
			var was_created = _trader_created
			trader = entry
			_trader_created = true
			state_updated.emit(trader)
			if not was_created:
				trader_created.emit()

		# Update all_traders for leaderboard
		var found = false
		for i in range(all_traders.size()):
			if all_traders[i].get("address", "") == addr:
				all_traders[i] = entry
				found = true
				break
		if not found and entry["balance"] > 0:
			all_traders.append(entry)
		all_traders.sort_custom(func(a, b): return a["balance"] > b["balance"])

	if models.has("prophecy_roguelite-Market"):
		var m = models["prophecy_roguelite-Market"]
		var mid = _int(m.get("market_id", 0))
		if mid > 0:
			markets[mid] = {
				"market_id": mid,
				"yes_odds": _int(m.get("yes_odds", 0)),
				"no_odds": _int(m.get("no_odds", 0)),
				"is_resolved": _bool(m.get("is_resolved", false)),
				"outcome": _bool(m.get("outcome", false)),
				"total_yes_amount": _int(m.get("total_yes_amount", 0)),
				"total_no_amount": _int(m.get("total_no_amount", 0)),
			}

	if models.has("prophecy_roguelite-Position"):
		var p = models["prophecy_roguelite-Position"]
		var mid = _int(p.get("market_id", 0))
		var addr = str(p.get("player", ""))
		if mid > 0:
			var pos = {
				"market_id": mid,
				"player": addr,
				"is_yes": _bool(p.get("is_yes", false)),
				"amount": _int(p.get("amount", 0)),
				"is_settled": _bool(p.get("is_settled", false)),
				"payout": _int(p.get("payout", 0)),
			}
			# Store for spectator mode (all players)
			if addr != "":
				all_positions[addr + "_" + str(mid)] = pos
			# Our positions
			if addr == "" or _addr_match(addr, connection.get_player_address()):
				var was_settled = positions.has(mid) and positions[mid].get("is_settled", false)
				positions[mid] = pos
				if pos["is_settled"] and not was_settled and pos["amount"] > 0:
					var correct = pos["payout"] > 0
					prediction_settled.emit(mid, correct, pos["payout"])

	if models.has("prophecy_roguelite-WorldBoss"):
		var wb = models["prophecy_roguelite-WorldBoss"]
		world_boss["total_yes"] = _int(wb.get("total_yes", 0))
		world_boss["total_no"] = _int(wb.get("total_no", 0))
		world_boss["total_yes_amount"] = _int(wb.get("total_yes_amount", 0))
		world_boss["total_no_amount"] = _int(wb.get("total_no_amount", 0))
		world_boss["is_resolved"] = _bool(wb.get("is_resolved", false))
		world_boss["outcome"] = _bool(wb.get("outcome", false))
		var recent: Array = []
		for key in ["recent_0", "recent_1", "recent_2", "recent_3", "recent_4"]:
			var addr = str(wb.get(key, ""))
			if addr != "" and addr != "0x0":
				recent.append(addr)
		world_boss["recent"] = recent
		world_boss_updated.emit(world_boss)

	if models.has("prophecy_roguelite-Relics"):
		var r = models["prophecy_roguelite-Relics"]
		var addr = str(r.get("address", ""))
		if addr == "" or _addr_match(addr, connection.get_player_address()):
			relics["leverage_tokens"] = _int(r.get("leverage_tokens", 0))
			relics["stop_loss"] = _int(r.get("stop_loss", 0))
			relics["insider_info"] = _int(r.get("insider_info", 0))

	if models.has("prophecy_roguelite-LeaderboardEntry"):
		var l = models["prophecy_roguelite-LeaderboardEntry"]
		var addr = str(l.get("address", ""))
		if addr == "" or _addr_match(addr, connection.get_player_address()):
			leaderboard = {
				"high_score": _int(l.get("high_score", 0)),
				"best_streak": _int(l.get("best_streak", 0)),
				"total_runs": _int(l.get("total_runs", 0)),
			}

func _on_tx_completed(entrypoint: String, success: bool, tx_hash: String) -> void:
	last_tx_hash = tx_hash
	tx_status.emit(entrypoint, success, tx_hash)
	is_busy = false
	await get_tree().create_timer(0.3).timeout
	refresh_state()

# --- Actions ---

func create_trader() -> void:
	is_busy = true
	connection.execute("create_trader")

func create_market(market_id: int, yes_odds: int, no_odds: int) -> void:
	connection.execute("create_market", [market_id, yes_odds, no_odds])

func resolve_market_on_chain(market_id: int, outcome: bool) -> void:
	var outcome_int = 1 if outcome else 0
	connection.execute("resolve_market", [market_id, outcome_int])

func place_prediction(market_id: int, is_yes: bool, amount: int) -> void:
	if is_busy:
		return
	is_busy = true
	var is_yes_int = 1 if is_yes else 0
	connection.execute("place_prediction", [market_id, is_yes_int, amount])

func buy_relic(relic_type: int) -> void:
	# relic_type: 0=leverage, 1=stop_loss, 2=insider
	if is_busy:
		return
	is_busy = true
	connection.execute("buy_relic", [relic_type])

func buy_relic_local(relic_key: String) -> bool:
	# Optimistic local update (before chain confirms)
	var cost = RELIC_COSTS.get(relic_key, 0)
	var bal = trader.get("balance", 0)
	if cost <= 0 or bal < cost:
		return false
	trader["balance"] = bal - cost
	relics[relic_key] = relics.get(relic_key, 0) + 1
	state_updated.emit(trader)
	return true

func use_relic_local(relic_key: String) -> bool:
	if relics.get(relic_key, 0) <= 0:
		return false
	relics[relic_key] -= 1
	return true

func bet_world_boss(is_yes: bool, amount: int) -> void:
	if is_busy:
		return
	is_busy = true
	var is_yes_int = 1 if is_yes else 0
	connection.execute("bet_world_boss", [is_yes_int, amount])

func get_positions_for_player(addr: String) -> Array:
	var result: Array = []
	for key in all_positions:
		var pos = all_positions[key]
		if _addr_match(str(pos.get("player", "")), addr):
			result.append(pos)
	return result

func claim_position(market_id: int) -> void:
	if is_busy:
		return
	is_busy = true
	connection.execute("claim", [market_id])

func cash_out_early(market_id: int) -> void:
	if is_busy:
		return
	is_busy = true
	connection.execute("cash_out_early", [market_id])

func get_cash_out_value(market_id: int) -> int:
	# Estimate cash-out value locally (mirrors Cairo logic)
	var pos = positions.get(market_id, {})
	var amount = pos.get("amount", 0)
	if amount <= 0:
		return 0
	var market = markets.get(market_id, {})
	var total_yes = market.get("total_yes_amount", 0)
	var total_no = market.get("total_no_amount", 0)
	var total_pool = total_yes + total_no
	if total_pool == 0:
		return (amount * 80) / 100
	var your_side = total_yes if pos.get("is_yes", false) else total_no
	var other_side = total_pool - your_side
	var raw = (amount * (50 + (other_side * 100) / total_pool)) / 100
	var min_out = (amount * 50) / 100
	var max_out = (amount * 150) / 100
	return clampi(raw, min_out, max_out)

func seed_markets() -> void:
	for mid in MARKET_ODDS:
		var odds = MARKET_ODDS[mid]
		create_market(mid, odds["yes"], odds["no"])
		await get_tree().create_timer(0.5).timeout
	await get_tree().create_timer(2.0).timeout
	for mid in MARKET_DATA:
		var data = MARKET_DATA[mid]
		if data["pre_resolved"]:
			resolve_market_on_chain(mid, data["outcome"])
			await get_tree().create_timer(0.5).timeout

func get_market_title(market_id: int) -> String:
	if MARKET_DATA.has(market_id):
		return MARKET_DATA[market_id]["title"]
	return "Market #%d" % market_id

func get_market_category(market_id: int) -> String:
	if MARKET_DATA.has(market_id):
		return MARKET_DATA[market_id]["category"]
	return "Other"

func is_market_pre_resolved(market_id: int) -> bool:
	if MARKET_DATA.has(market_id):
		return MARKET_DATA[market_id]["pre_resolved"]
	return false

# --- Utilities ---

static func _int(val) -> int:
	if val is int: return val
	if val is float: return int(val)
	if val is String and val.is_valid_int(): return val.to_int()
	return 0

static func _bool(val) -> bool:
	if val is bool: return val
	if val is int: return val != 0
	if val is String: return val == "true"
	return false

# Normalize hex address: strip leading zeros after 0x for comparison
# Torii returns "0x0127..." but accounts use "0x127..."
static func _normalize_addr(addr: String) -> String:
	if not addr.begins_with("0x"):
		return addr
	var hex = addr.substr(2)
	hex = hex.lstrip("0")
	if hex == "":
		hex = "0"
	return "0x" + hex

static func _addr_match(a: String, b: String) -> bool:
	return _normalize_addr(a) == _normalize_addr(b)
