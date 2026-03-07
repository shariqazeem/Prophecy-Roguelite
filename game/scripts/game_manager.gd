class_name GameManager
extends Node

signal state_updated(data: Dictionary)
signal round_resolved(round_data: Dictionary)
signal player_died(score: int)
signal player_spawned()
signal tx_status(entrypoint: String, success: bool, tx_hash: String)

@onready var connection: DojoConnection = $DojoConnection

var player: Dictionary = {"is_alive": false}
var last_round: Dictionary = {}
var leaderboard: Dictionary = {}
var is_busy: bool = false
var last_tx_hash: String = ""

var _awaiting_round: bool = false
var _spawn_requested: bool = false

func _ready() -> void:
	connection.connected.connect(_on_connected)
	connection.tx_completed.connect(_on_tx_completed)

func _on_connected() -> void:
	connection.subscribe_entities(_on_entity_update)
	await get_tree().create_timer(0.3).timeout
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
	if models.has("prophecy_roguelite-Player"):
		var p = models["prophecy_roguelite-Player"]
		var was_alive = player.get("is_alive", false)

		player = {
			"hp": _int(p.get("hp", 0)),
			"max_hp": _int(p.get("max_hp", 100)),
			"floor": _int(p.get("floor", 0)),
			"gold": _int(p.get("gold", 0)),
			"streak": _int(p.get("prediction_streak", 0)),
			"best_streak": _int(p.get("best_streak", 0)),
			"total": _int(p.get("total_predictions", 0)),
			"correct": _int(p.get("correct_predictions", 0)),
			"is_alive": _bool(p.get("is_alive", true)),
			"clue_type": _int(p.get("clue_type", 0)),
			"clue_detail": _int(p.get("clue_detail", 0)),
			"streak_tier": _int(p.get("streak_tier", 0)),
		}
		state_updated.emit(player)

		if was_alive and not player["is_alive"]:
			player_died.emit(_score())
		if not was_alive and player["is_alive"] and player.get("floor", -1) == 0:
			_spawn_requested = false
			player_spawned.emit()
		elif _spawn_requested and player["is_alive"] and player.get("floor", -1) == 0:
			_spawn_requested = false
			player_spawned.emit()

	if models.has("prophecy_roguelite-GameRound") and _awaiting_round:
		var r = models["prophecy_roguelite-GameRound"]
		_awaiting_round = false
		last_round = {
			"floor": _int(r.get("floor", 0)),
			"event": _event(r.get("event_type", "Monster")),
			"prediction": _event(r.get("player_prediction", "Monster")),
			"damage": _int(r.get("damage_dealt", 0)),
			"gold": _int(r.get("gold_earned", 0)),
			"heal": _int(r.get("hp_healed", 0)),
			"correct": _bool(r.get("was_correct", false)),
			"wager": _int(r.get("wager_amount", 0)),
			"is_boss": _bool(r.get("is_boss", false)),
		}
		round_resolved.emit(last_round)

	if models.has("prophecy_roguelite-LeaderboardEntry"):
		var l = models["prophecy_roguelite-LeaderboardEntry"]
		leaderboard = {
			"high_score": _int(l.get("high_score", 0)),
			"highest_floor": _int(l.get("highest_floor", 0)),
			"best_streak": _int(l.get("best_streak", 0)),
			"total_runs": _int(l.get("total_runs", 0)),
		}

func _on_tx_completed(entrypoint: String, success: bool, tx_hash: String) -> void:
	last_tx_hash = tx_hash
	tx_status.emit(entrypoint, success, tx_hash)
	is_busy = false
	await get_tree().create_timer(0.3).timeout
	refresh_state()

func spawn() -> void:
	is_busy = true
	_awaiting_round = false
	_spawn_requested = true
	connection.execute("spawn")

func predict(choice: int, wager: int = 0) -> void:
	if is_busy:
		return
	is_busy = true
	_awaiting_round = true
	connection.execute("predict_and_advance", [choice, wager])

func _score() -> int:
	var acc = 0
	if player.get("total", 0) > 0:
		acc = (player["correct"] * 100) / player["total"]
	return (player.get("floor", 0) * 10) + player.get("gold", 0) + acc + (player.get("best_streak", 0) * 5)

# --- Safe type conversions (Torii returns mixed types) ---
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

static func _event(val) -> int:
	if val is String:
		match val:
			"Monster": return 0
			"Trap": return 1
			"Treasure": return 2
			"Heal": return 3
	if val is int: return val
	if val is float: return int(val)
	return 0

static func event_name(t: int) -> String:
	return ["CRASH", "RUG", "MOON", "RALLY"][t] if t >= 0 and t < 4 else "?"

static func event_color(t: int) -> Color:
	return [Color("ef4444"), Color("f59e0b"), Color("10b981"), Color("6366f1")][t] if t >= 0 and t < 4 else Color.WHITE
