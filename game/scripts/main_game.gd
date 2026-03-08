## Main UI controller for the Prophecy roguelite.
##
## Manages an 8-panel roguelite flow: Intro -> Start -> Dashboard -> Swipe
## (rounds of 10 cards) -> RoundSummary -> repeat, with Portfolio, Leaderboard,
## LiquidatedPanel, Dark Pool Shop, World Boss, and Oracle Admin as overlays.
##
## All UI is constructed programmatically in _ready() — no .tscn edits needed
## for styling. Swipe gestures (right=YES, left=NO, up=SKIP) drive predictions.
## Features: streak system, elite/boss cards, event nodes, flow state combo,
## procedural SFX, cinematic intro, tween animations, and dynamic card tinting.
extends Control

@onready var gm: GameManager = %GameManager

# Panels
@onready var start_panel: PanelContainer = %StartPanel
@onready var dashboard_panel: PanelContainer = %DashboardPanel
@onready var swipe_panel: PanelContainer = %SwipePanel
@onready var portfolio_panel: PanelContainer = %PortfolioPanel
@onready var leaderboard_panel: PanelContainer = %LeaderboardPanel
@onready var liquidated_panel: PanelContainer = %LiquidatedPanel
@onready var round_summary_panel: PanelContainer = %RoundSummaryPanel

# Start
@onready var btn_start: Button = %BtnStart
@onready var start_status: Label = %StartStatus

# Dashboard
@onready var balance_label: Label = %BalanceLabel
@onready var pnl_label: Label = %PnlLabel
@onready var stat_markets: Label = %StatMarkets
@onready var stat_accuracy: Label = %StatAccuracy
@onready var stat_streak: Label = %StatStreak
@onready var btn_markets: Button = %BtnMarkets
@onready var btn_portfolio: Button = %BtnPortfolio
@onready var btn_dash_lb: Button = %BtnDashLB
@onready var chain_status: Label = %ChainStatus
@onready var tx_label: Label = %TxLabel

# Swipe
@onready var btn_swipe_back: Button = %BtnSwipeBack
@onready var swipe_progress: Label = %SwipeProgress
@onready var timer_label: Label = %TimerLabel
@onready var swipe_balance: Label = %SwipeBalance
@onready var round_info: Label = %RoundInfo
@onready var card_area: Control = %CardArea
@onready var card_container: Control = %CardContainer
@onready var card_panel: PanelContainer = %CardPanel
@onready var card_category: Label = %CardCategory
@onready var card_question: Label = %CardQuestion
@onready var card_status: Label = %CardStatus
@onready var card_yes_odds: Label = %CardYesOdds
@onready var card_no_odds: Label = %CardNoOdds
@onready var yes_stamp: Label = %YesStamp
@onready var no_stamp: Label = %NoStamp
@onready var skip_stamp: Label = %SkipStamp
@onready var wager_bar: HBoxContainer = %WagerBar
@onready var btn_w100: Button = %BtnW100
@onready var btn_w500: Button = %BtnW500
@onready var btn_w1k: Button = %BtnW1K
@onready var btn_wall: Button = %BtnWAll
@onready var wager_label: Label = %WagerLabel
@onready var all_done_label: Label = %AllDoneLabel

# Liquidated
@onready var liq_stats: Label = %LiqStats
@onready var btn_new_run: Button = %BtnNewRun

# Round Summary
@onready var round_title: Label = %RoundTitle
@onready var round_pnl: Label = %RoundPnl
@onready var round_stats: Label = %RoundStats
@onready var btn_next_round: Button = %BtnNextRound
@onready var btn_rnd_portfolio: Button = %BtnRndPortfolio

# Portfolio
@onready var port_list: VBoxContainer = %PortList
@onready var btn_port_back: Button = %BtnPortBack

# Leaderboard
@onready var lb_entries: VBoxContainer = %LBEntries
@onready var btn_lb_back: Button = %BtnLBBack

# Flash
@onready var flash_rect: ColorRect = %FlashRect
@onready var background: ColorRect = $Background

var _return_to: String = "dashboard"

# Swipe state
enum SwipeDirection { RIGHT, LEFT, UP }
const SWIPE_THRESHOLD: float = 100.0
const SWIPE_UP_THRESHOLD: float = 80.0

var _market_queue: Array[int] = []
var _queue_index: int = 0
var _swipe_wager: int = 500
var _input_locked: bool = false
var _awaiting_result: bool = false
var _dragging: bool = false
var _drag_start: Vector2
var _drag_offset: Vector2

# Round system
const ROUND_SIZE: int = 10
const CARD_TIME_LIMIT: float = 30.0
var _round_number: int = 1
var _round_card_index: int = 0  # 0-9 within current round
var _round_correct: int = 0
var _round_wrong: int = 0
var _round_start_balance: int = 10000
var _time_remaining: float = CARD_TIME_LIMIT
var _timer_active: bool = false
var _last_tick: int = -1

# Relics state
var _active_relic: String = ""  # "leverage_tokens", "stop_loss", "insider_info", or ""

# Volatility events
enum VolatilityEvent { NONE, FLASH_CRASH, BULL_RUN, BEAR_TRAP }
var _current_event: int = VolatilityEvent.NONE
var _event_label: Label = null

# Relic bar UI references
var _relic_bar: HBoxContainer = null
var _btn_leverage: Button = null
var _btn_stop_loss: Button = null
var _btn_insider: Button = null

# Dark Pool Shop UI
var _shop_panel: PanelContainer = null
var _shop_continue_btn: Button = null
var _shop_from_dashboard: bool = false

# World Boss UI
var _world_boss_panel: PanelContainer = null
var _wb_yes_bar: ColorRect = null
var _wb_no_bar: ColorRect = null
var _wb_ratio_label: Label = null
var _wb_feed: VBoxContainer = null
var _wb_sync_label: Label = null
var _wb_your_bet_label: Label = null
var _wb_bet_yes_btn: Button = null
var _wb_bet_no_btn: Button = null
var _wb_has_bet: bool = false
var _wb_bet_side: String = ""  # "YES" or "NO"

# Spectator Modal
var _spectator_panel: PanelContainer = null

# Rapid Fire
var _rapid_fire_active: bool = false
var _rapid_fire_remaining: int = 0
var _session_key_label: Label = null

# Card types: Elite (card 5) and Boss (card 10)
enum CardType { STANDARD, ELITE, BOSS, EVENT }
var _current_card_type: int = CardType.STANDARD

# Flow State / Combo system
var _combo: int = 0
var _in_flow_state: bool = false
var _combo_label: Label = null
var _event_panel: PanelContainer = null

# Cinematic Intro
var _intro_panel: PanelContainer = null
var _intro_terminal: RichTextLabel = null
var _intro_active: bool = false

# Diegetic UI: card slot brackets
var _bracket_left: Label = null
var _bracket_right: Label = null

# Oracle Admin Panel (Ctrl+Shift+O)
var _oracle_panel: PanelContainer = null
var _oracle_list: VBoxContainer = null

func _ready() -> void:
	gm.state_updated.connect(_on_state)
	gm.trader_created.connect(_on_trader_created)
	gm.prediction_settled.connect(_on_prediction_settled)
	gm.tx_status.connect(_on_tx)
	gm.connection.tx_started.connect(_on_tx_started)

	# Start
	btn_start.pressed.connect(_start)

	# Dashboard nav
	btn_markets.pressed.connect(_show_swipe)
	btn_portfolio.pressed.connect(func(): _show_portfolio("dashboard"))
	btn_dash_lb.pressed.connect(func(): _show_leaderboard("dashboard"))

	# Row: Start Trading + Dark Pool side by side
	var dash_row = HBoxContainer.new()
	dash_row.add_theme_constant_override("separation", 8)
	var parent_vbox = btn_markets.get_parent()
	var markets_idx = btn_markets.get_index()
	parent_vbox.add_child(dash_row)
	parent_vbox.move_child(dash_row, markets_idx)
	parent_vbox.remove_child(btn_markets)
	dash_row.add_child(btn_markets)
	btn_markets.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var btn_shop = Button.new()
	btn_shop.name = "BtnShop"
	btn_shop.text = "DARK POOL"
	btn_shop.add_theme_font_size_override("font_size", 20)
	btn_shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_button_style(btn_shop, Color("8b5cf6"))
	btn_shop.pressed.connect(func(): _show_shop_from_dashboard())
	dash_row.add_child(btn_shop)
	_apply_button_juice(btn_shop)

	# New Run button (hidden by default, shown when balance = 0)
	var btn_dash_new_run = Button.new()
	btn_dash_new_run.name = "BtnDashNewRun"
	btn_dash_new_run.text = "NEW RUN ($10,000)"
	btn_dash_new_run.add_theme_font_size_override("font_size", 20)
	btn_dash_new_run.visible = false
	_apply_button_style(btn_dash_new_run, Color("ef4444"))
	btn_dash_new_run.pressed.connect(_new_run)
	parent_vbox.add_child(btn_dash_new_run)
	parent_vbox.move_child(btn_dash_new_run, dash_row.get_index() + 1)
	_apply_button_juice(btn_dash_new_run)

	# World Boss banner on dashboard
	var wb_banner = _create_world_boss_banner()
	parent_vbox.add_child(wb_banner)

	# Swipe
	btn_swipe_back.pressed.connect(_show_dashboard)
	card_container.gui_input.connect(_on_card_input)
	btn_w100.pressed.connect(func(): _set_swipe_wager(100))
	btn_w500.pressed.connect(func(): _set_swipe_wager(500))
	btn_w1k.pressed.connect(func(): _set_swipe_wager(1000))
	btn_wall.pressed.connect(func(): _set_swipe_wager(gm.trader.get("balance", 0)))

	# Liquidated
	btn_new_run.pressed.connect(_new_run)

	# Round summary
	btn_next_round.pressed.connect(_start_next_round)
	btn_rnd_portfolio.pressed.connect(func(): _show_portfolio("swipe"))

	# Portfolio
	btn_port_back.pressed.connect(func(): _nav_back())

	# Leaderboard
	btn_lb_back.pressed.connect(func(): _nav_back())

	# Style buttons — obsidian purple/cyan palette
	_apply_button_style(btn_start, Color("a855f7"))
	_apply_button_style(btn_markets, Color("a855f7"))
	_apply_button_style(btn_portfolio, Color("38bdf8"))
	_apply_button_style(btn_dash_lb, Color("8b8da0"))
	_apply_button_style(btn_swipe_back, Color("8b8da0"))
	_apply_button_style(btn_port_back, Color("8b8da0"))
	_apply_button_style(btn_lb_back, Color("8b8da0"))
	_apply_button_style(btn_w100, Color("8b8da0"))
	_apply_button_style(btn_w500, Color("a855f7"))
	_apply_button_style(btn_w1k, Color("ef4444"))
	_apply_button_style(btn_wall, Color("38bdf8"))
	_apply_button_style(btn_new_run, Color("ef4444"))
	_apply_button_style(btn_next_round, Color("a855f7"))
	_apply_button_style(btn_rnd_portfolio, Color("38bdf8"))

	# Obsidian panel styling
	_apply_panel_obsidian()
	_apply_card_glass_style()

	# Button hover juice
	for btn in [btn_start, btn_markets, btn_portfolio, btn_dash_lb, btn_swipe_back,
			btn_port_back, btn_lb_back, btn_w100, btn_w500, btn_w1k, btn_wall,
			btn_new_run, btn_next_round, btn_rnd_portfolio]:
		_apply_button_juice(btn)

	# Relic bar below wager bar
	_build_relic_bar()
	# Dark Pool Shop (between rounds)
	_build_shop_panel()
	# Volatility event label above round_info
	_build_event_label()
	# World Boss panel
	_build_world_boss_panel()
	# Spectator modal
	_build_spectator_panel()
	# Session key label (for Rapid Fire flex)
	_build_session_key_label()
	# Combo / Flow State label
	_build_combo_label()
	# Event Node panel
	_build_event_node_panel()
	# Connect world boss updates
	gm.world_boss_updated.connect(_on_world_boss_updated)

	# Post-processing: WorldEnvironment glow + CRT overlay
	_setup_post_processing()
	_setup_crt_overlay()

	# Diegetic UI: card slot brackets + letter spacing
	_build_card_slot_brackets()
	_apply_letter_spacing()

	# Cinematic intro instead of static start screen
	_build_intro_panel()
	_play_intro_sequence()

func _process(delta: float) -> void:
	# Holographic card tilt (runs regardless of timer)
	_update_card_tilt(delta)

	if not _timer_active:
		return
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		_time_remaining = 0.0
		_timer_active = false
		timer_label.text = "0:00"
		# Auto-skip on timeout
		if not _input_locked:
			_input_locked = true
			_commit_swipe(SwipeDirection.UP)
		return

	var secs = int(ceil(_time_remaining))
	timer_label.text = "0:%02d" % secs

	# Color warning
	if _time_remaining <= 5.0:
		timer_label.add_theme_color_override("font_color", Color("ef4444"))
		# Tick sound at each second
		if secs != _last_tick and _time_remaining <= 5.0:
			_last_tick = secs
			SFX.play_tick(self)
	elif _time_remaining <= 10.0:
		timer_label.add_theme_color_override("font_color", Color("a855f7"))
	else:
		timer_label.add_theme_color_override("font_color", Color("38bdf8"))

# === SCREENS ===

func _hide_all() -> void:
	_timer_active = false
	start_panel.visible = false
	dashboard_panel.visible = false
	swipe_panel.visible = false
	portfolio_panel.visible = false
	leaderboard_panel.visible = false
	liquidated_panel.visible = false
	round_summary_panel.visible = false
	if _shop_panel:
		_shop_panel.visible = false
	if _world_boss_panel:
		_world_boss_panel.visible = false
	if _spectator_panel:
		_spectator_panel.visible = false
	if _event_panel:
		_event_panel.visible = false
	if _intro_panel:
		_intro_panel.visible = false
	if _oracle_panel:
		_oracle_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_O and event.ctrl_pressed and event.shift_pressed:
			_toggle_oracle_panel()
			get_viewport().set_input_as_handled()

func _show_start() -> void:
	_hide_all()
	start_panel.visible = true
	start_status.text = ""
	btn_start.disabled = false
	# Pulsing glow on start button
	_pulse_button(btn_start)

func _show_dashboard() -> void:
	_hide_all()
	dashboard_panel.visible = true
	_update_dashboard()

func _show_swipe() -> void:
	_hide_all()
	swipe_panel.visible = true
	_round_number = 1
	_build_queue()
	_start_round()

func _show_portfolio(return_to: String) -> void:
	_return_to = return_to
	_hide_all()
	portfolio_panel.visible = true
	_populate_portfolio()

func _show_leaderboard(return_to: String) -> void:
	_return_to = return_to
	_hide_all()
	leaderboard_panel.visible = true
	_populate_leaderboard()

func _show_liquidated() -> void:
	_hide_all()
	liquidated_panel.visible = true
	SFX.play_liquidated(self)
	SFX.play_heavy_impact(self)
	_flash(Color(0.94, 0.27, 0.27, 0.3))
	_shake(12.0, 0.4)
	_camera_kick(0.1)
	_muffle_audio()

	var played = gm.trader.get("markets_played", 0)
	var correct = gm.trader.get("correct_predictions", 0)
	var streak = gm.trader.get("best_streak", gm.trader.get("streak", 0))
	var acc = (correct * 100 / played) if played > 0 else 0
	liq_stats.text = "Round %d · %d markets · %d%% accuracy · Best streak: %dx" % [_round_number, played, acc, streak]

func _show_round_summary() -> void:
	_hide_all()
	round_summary_panel.visible = true
	SFX.play_round_complete(self)

	round_title.text = "ROUND %d COMPLETE" % _round_number

	var bal = gm.trader.get("balance", 0)
	var pnl = bal - _round_start_balance
	if pnl >= 0:
		round_pnl.text = "+$%s" % _format_number(pnl)
		round_pnl.add_theme_color_override("font_color", Color("10b981"))
	else:
		round_pnl.text = "-$%s" % _format_number(absi(pnl))
		round_pnl.add_theme_color_override("font_color", Color("ef4444"))

	var total_in_round = _round_correct + _round_wrong
	var streak = gm.trader.get("streak", 0)
	round_stats.text = "%d/%d correct · %dx streak · $%s balance" % [_round_correct, total_in_round, streak, _format_number(bal)]

	# Hide next round if no more markets
	btn_next_round.visible = _queue_index < _market_queue.size()

func _nav_back() -> void:
	if _return_to == "dashboard":
		_show_dashboard()
	else:
		_show_swipe()

# === DASHBOARD ===

func _update_dashboard() -> void:
	var bal = gm.trader.get("balance", 10000)
	balance_label.text = "$%s" % _format_number(bal)

	var pnl = bal - 10000
	if pnl > 0:
		pnl_label.text = "+$%s P&L" % _format_number(pnl)
		pnl_label.add_theme_color_override("font_color", Color("10b981"))
	elif pnl < 0:
		pnl_label.text = "-$%s P&L" % _format_number(absi(pnl))
		pnl_label.add_theme_color_override("font_color", Color("ef4444"))
	else:
		pnl_label.text = "$0 P&L"
		pnl_label.add_theme_color_override("font_color", Color("8b8da0"))

	var played = gm.trader.get("markets_played", 0)
	stat_markets.text = "%d Markets" % played

	var correct = gm.trader.get("correct_predictions", 0)
	if played > 0:
		stat_accuracy.text = "%d%% Accuracy" % ((correct * 100) / played)
	else:
		stat_accuracy.text = "- Accuracy"

	var streak = gm.trader.get("streak", 0)
	stat_streak.text = "%dx Streak" % streak

	var addr = gm.connection.get_player_address()
	var short = addr.left(10) + "..." if addr.length() > 10 else addr
	var slot_label = "Slot" if gm.connection.use_slot else "Katana"
	chain_status.text = "Starknet · %s · %s" % [slot_label, short]

	# Show New Run button when broke, disable trading
	var is_broke = bal <= 0
	btn_markets.disabled = is_broke
	var shop_btn = dashboard_panel.find_child("BtnShop", true, false) as Button
	if shop_btn:
		shop_btn.disabled = is_broke
	var new_run_btn = dashboard_panel.find_child("BtnDashNewRun", true, false) as Button
	if new_run_btn:
		new_run_btn.visible = is_broke

# === ROUND SYSTEM ===

func _build_queue() -> void:
	_market_queue.clear()
	_queue_index = 0
	for mid in GameManager.MARKET_DATA:
		var has_position = gm.positions.has(mid) and gm.positions[mid].get("amount", 0) > 0
		if not has_position:
			_market_queue.append(mid)
	_market_queue.shuffle()

func _start_round() -> void:
	_round_card_index = 0
	_round_correct = 0
	_round_wrong = 0
	_round_start_balance = gm.trader.get("balance", 10000)
	_active_relic = ""
	_update_swipe_wager_label()
	_update_relic_bar()

	if _queue_index >= _market_queue.size():
		_show_all_done()
		return

	# Roll volatility event (round >= 2, 60% chance of event)
	_roll_volatility_event()

	# Rapid Fire: every 3rd round, inject a 5-card burst with 3s timer
	# "Only possible with Cartridge Session Keys. Standard wallets would
	# popup 5 approval dialogs and destroy the flow."
	if _round_number >= 3 and _round_number % 3 == 0:
		_rapid_fire_active = true
		_rapid_fire_remaining = 5
		_show_rapid_fire_popup()
	else:
		_rapid_fire_active = false
		_rapid_fire_remaining = 0

	all_done_label.visible = false
	card_container.visible = true
	wager_bar.visible = true
	if _relic_bar:
		_relic_bar.visible = true
	_populate_card()

func _start_next_round() -> void:
	_round_number += 1
	_show_shop()

func _new_run() -> void:
	# Restart: create new trader, reset state
	_hide_all()
	start_panel.visible = true
	start_status.text = "Creating new trader..."
	btn_start.disabled = true
	gm.create_trader()

func _current_market_id() -> int:
	if _queue_index < _market_queue.size():
		return _market_queue[_queue_index]
	return -1

func _populate_card() -> void:
	var mid = _current_market_id()
	if mid < 0:
		_show_all_done()
		return

	var data = GameManager.MARKET_DATA.get(mid, {})
	var odds = GameManager.MARKET_ODDS.get(mid, {"yes": 200, "no": 200})
	var on_chain = gm.markets.get(mid, {})

	# Determine card type by position in round
	if _round_card_index == 4:
		_current_card_type = CardType.ELITE
	elif _round_card_index == 9:
		_current_card_type = CardType.BOSS
	else:
		_current_card_type = CardType.STANDARD

	card_category.text = data.get("category", "").to_upper()
	card_question.text = data.get("title", "Unknown Market")

	# Card type label prefix
	match _current_card_type:
		CardType.ELITE:
			card_category.text = "ELITE · " + card_category.text
			card_category.add_theme_color_override("font_color", Color("f59e0b"))
		CardType.BOSS:
			card_category.text = "BOSS · " + card_category.text
			card_category.add_theme_color_override("font_color", Color("ef4444"))
		_:
			card_category.add_theme_color_override("font_color", Color("8b8da0"))

	var is_resolved = on_chain.get("is_resolved", data.get("pre_resolved", false))
	if is_resolved:
		card_status.text = "Resolved — instant result!"
		card_status.add_theme_color_override("font_color", Color("10b981"))
	else:
		card_status.text = "Open — goes to portfolio"
		card_status.add_theme_color_override("font_color", Color("38bdf8"))

	# Insider Info relic: reveal correct answer for pre-resolved markets
	if _active_relic == "insider_info" and data.get("pre_resolved", false):
		var answer = "YES" if data.get("outcome", false) else "NO"
		card_status.text = "INSIDER: Answer is %s" % answer
		card_status.add_theme_color_override("font_color", Color("a855f7"))

	var y = on_chain.get("yes_odds", odds["yes"])
	var n = on_chain.get("no_odds", odds["no"])
	card_yes_odds.text = "YES %.1fx" % [y / 100.0]
	card_no_odds.text = "NO %.1fx" % [n / 100.0]

	# Update header
	swipe_progress.text = "%d / %d" % [_round_card_index + 1, ROUND_SIZE]
	var bal = gm.trader.get("balance", 10000)
	swipe_balance.text = "$%s" % _format_number(bal)

	# Round info with streak
	var streak = gm.trader.get("streak", 0)
	var streak_text = ""
	if streak >= 7:
		streak_text = " · ORACLE %dx" % streak
		round_info.add_theme_color_override("font_color", Color("a855f7"))
	elif streak >= 4:
		streak_text = " · ON FIRE %dx" % streak
		round_info.add_theme_color_override("font_color", Color("ef4444"))
	elif streak >= 2:
		streak_text = " · HOT HAND %dx" % streak
		round_info.add_theme_color_override("font_color", Color("f59e0b"))
	else:
		round_info.add_theme_color_override("font_color", Color("e0e0f0"))
	round_info.text = "ROUND %d%s" % [_round_number, streak_text]

	# Streak punch animation on round_info
	if streak >= 2:
		round_info.pivot_offset = round_info.size / 2.0
		round_info.scale = Vector2(1.5, 1.5)
		var punch_tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		punch_tw.tween_property(round_info, "scale", Vector2.ONE, 0.35)

	# Reset card glass border to purple
	_apply_card_glass_style()

	# Elite/Boss card border glow
	match _current_card_type:
		CardType.ELITE:
			_set_card_border_color(Color(0.96, 0.62, 0.04, 0.6))
		CardType.BOSS:
			_set_card_border_color(Color(0.94, 0.27, 0.27, 0.7))

	# Reset card visual
	card_container.position = Vector2.ZERO
	card_container.rotation = 0.0
	card_panel.rotation = 0.0
	card_container.modulate.a = 1.0
	yes_stamp.modulate.a = 0.0
	no_stamp.modulate.a = 0.0
	skip_stamp.modulate.a = 0.0
	_input_locked = false
	_awaiting_result = false
	_dragging = false

	# Boss: force 50% balance wager
	if _current_card_type == CardType.BOSS:
		_swipe_wager = maxi(bal / 2, 100)
	# Clamp wager to balance
	_swipe_wager = clampi(_swipe_wager, 100, maxi(bal, 100))
	_update_swipe_wager_label()
	if _current_card_type == CardType.BOSS:
		wager_label.text = "BOSS WAGER: $%s (50%%)" % _format_number(_swipe_wager)
	# Update combo display
	_update_combo_display()

	# Start timer — Rapid Fire = 3s, Bear Trap = 10s, Normal = 30s
	if _rapid_fire_active and _rapid_fire_remaining > 0:
		_time_remaining = 3.0
		timer_label.text = "0:03"
		timer_label.add_theme_color_override("font_color", Color("ef4444"))
		_rapid_fire_remaining -= 1
		# Show session key auto-sign flex
		if _session_key_label:
			_session_key_label.visible = true
			_session_key_label.modulate.a = 1.0
	elif _current_event == VolatilityEvent.BEAR_TRAP:
		_time_remaining = 10.0
		timer_label.text = "0:10"
	else:
		_time_remaining = CARD_TIME_LIMIT
		timer_label.text = "0:30"
		if _session_key_label:
			_session_key_label.visible = false
	_timer_active = true
	_last_tick = -1
	timer_label.add_theme_color_override("font_color", Color("38bdf8"))

func _show_all_done() -> void:
	_timer_active = false
	card_container.visible = false
	wager_bar.visible = false
	if _relic_bar:
		_relic_bar.visible = false
	all_done_label.visible = true

# --- Gesture detection ---

func _on_card_input(event: InputEvent) -> void:
	if _input_locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_drag_start = event.position
			_drag_offset = Vector2.ZERO
		else:
			_dragging = false
			_evaluate_swipe(_drag_offset)
	elif event is InputEventMouseMotion and _dragging:
		_drag_offset = event.position - _drag_start
		_update_card_drag(_drag_offset)

func _update_card_drag(offset: Vector2) -> void:
	card_container.position = offset
	card_container.rotation = clampf(offset.x / 600.0, -1.0, 1.0) * 0.26

	yes_stamp.modulate.a = clampf((offset.x - 30.0) / 70.0, 0.0, 1.0)
	no_stamp.modulate.a = clampf((-offset.x - 30.0) / 70.0, 0.0, 1.0)
	skip_stamp.modulate.a = clampf((-offset.y - 30.0) / 50.0, 0.0, 1.0) if absf(offset.y) > absf(offset.x) else 0.0

	# Diegetic card tint: green (YES) / red (NO) based on drag direction
	var norm_x = clampf(offset.x / 150.0, -1.0, 1.0)
	if norm_x > 0.05:
		card_panel.self_modulate = Color(1.0, 1.0, 1.0).lerp(Color(0.7, 1.0, 0.8), norm_x)
	elif norm_x < -0.05:
		card_panel.self_modulate = Color(1.0, 1.0, 1.0).lerp(Color(1.0, 0.75, 0.75), -norm_x)
	else:
		card_panel.self_modulate = Color.WHITE

func _evaluate_swipe(offset: Vector2) -> void:
	var dx = offset.x
	var dy = offset.y

	if -dy > SWIPE_UP_THRESHOLD and absf(dy) > absf(dx):
		_commit_swipe(SwipeDirection.UP)
	elif dx > SWIPE_THRESHOLD:
		_commit_swipe(SwipeDirection.RIGHT)
	elif dx < -SWIPE_THRESHOLD:
		_commit_swipe(SwipeDirection.LEFT)
	else:
		_snap_back()

func _snap_back() -> void:
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(card_container, "position", Vector2.ZERO, 0.25)
	tw.parallel().tween_property(card_container, "rotation", 0.0, 0.25)
	tw.parallel().tween_property(yes_stamp, "modulate:a", 0.0, 0.15)
	tw.parallel().tween_property(no_stamp, "modulate:a", 0.0, 0.15)
	tw.parallel().tween_property(skip_stamp, "modulate:a", 0.0, 0.15)
	tw.parallel().tween_property(card_panel, "self_modulate", Color.WHITE, 0.15)

func _commit_swipe(direction: SwipeDirection) -> void:
	_input_locked = true
	_timer_active = false
	card_panel.rotation = 0.0  # Reset tilt before fly-off
	card_panel.self_modulate = Color.WHITE  # Reset tint
	SFX.play_swipe(self)
	# TRANS_EXPO for extreme snap velocity
	var tw = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)

	match direction:
		SwipeDirection.RIGHT:
			tw.tween_property(card_container, "position", Vector2(900, 60), 0.2)
			tw.parallel().tween_property(yes_stamp, "modulate:a", 1.0, 0.06)
		SwipeDirection.LEFT:
			tw.tween_property(card_container, "position", Vector2(-900, 60), 0.2)
			tw.parallel().tween_property(no_stamp, "modulate:a", 1.0, 0.06)
		SwipeDirection.UP:
			tw.tween_property(card_container, "position", Vector2(0, -700), 0.2)
			tw.parallel().tween_property(skip_stamp, "modulate:a", 1.0, 0.06)

	tw.parallel().tween_property(card_container, "modulate:a", 0.0, 0.18)
	tw.tween_callback(_on_swipe_done.bind(direction))

func _on_swipe_done(direction: SwipeDirection) -> void:
	var mid = _current_market_id()
	if mid < 0:
		_advance_card()
		return

	if direction == SwipeDirection.UP:
		_advance_card()
		return

	var is_yes = (direction == SwipeDirection.RIGHT)
	var bal = gm.trader.get("balance", 0)
	var wager = clampi(_swipe_wager, 1, bal)

	# Volatility: Bull Run forces ALL IN
	if _current_event == VolatilityEvent.BULL_RUN:
		wager = bal

	# Elite: minimum wager $200
	if _current_card_type == CardType.ELITE:
		wager = maxi(wager, mini(200, bal))
	# Boss: force 50% of balance
	elif _current_card_type == CardType.BOSS:
		wager = maxi(bal / 2, 1)

	# Relic: Leverage triples the wager
	if _active_relic == "leverage_tokens":
		wager = clampi(wager * 3, 1, bal)
	# Relic: Stop-loss caps wager at $100 (safety net)
	elif _active_relic == "stop_loss":
		wager = mini(wager, 100)

	if wager <= 0:
		card_status.text = "No balance left!"
		card_status.add_theme_color_override("font_color", Color("ef4444"))
		_reset_card_for_retry()
		return

	# Consume active relic
	if _active_relic != "":
		gm.use_relic_local(_active_relic)
		_active_relic = ""
		_update_relic_bar()

	_awaiting_result = true
	var pick = "YES" if is_yes else "NO"
	card_container.position = Vector2.ZERO
	card_container.modulate.a = 1.0
	card_container.rotation = 0.0
	yes_stamp.modulate.a = 0.0
	no_stamp.modulate.a = 0.0
	skip_stamp.modulate.a = 0.0
	card_status.text = "Placing %s for $%s..." % [pick, _format_number(wager)]
	card_status.add_theme_color_override("font_color", Color("a855f7"))
	card_container.visible = true

	gm.place_prediction(mid, is_yes, wager)

func _advance_card() -> void:
	_queue_index += 1
	_round_card_index += 1

	# Check if round complete
	if _round_card_index >= ROUND_SIZE:
		_show_round_summary()
		return

	# Check if out of markets
	if _queue_index >= _market_queue.size():
		_show_round_summary()
		return

	# Event Node: card 7 (index 6) is a narrative encounter
	if _round_card_index == 6:
		_show_event_node()
		return

	_populate_card()

func _reset_card_for_retry() -> void:
	card_container.position = Vector2.ZERO
	card_container.modulate.a = 1.0
	card_container.rotation = 0.0
	yes_stamp.modulate.a = 0.0
	no_stamp.modulate.a = 0.0
	skip_stamp.modulate.a = 0.0
	_input_locked = false
	_awaiting_result = false
	_time_remaining = CARD_TIME_LIMIT
	_timer_active = true

# --- Wager bar ---

func _set_swipe_wager(amount: int) -> void:
	_swipe_wager = clampi(amount, 100, maxi(gm.trader.get("balance", 0), 100))
	_update_swipe_wager_label()

func _update_swipe_wager_label() -> void:
	wager_label.text = "Wager: $%s" % _format_number(_swipe_wager)

# === PORTFOLIO ===

func _populate_portfolio() -> void:
	for child in port_list.get_children():
		child.queue_free()

	var open_positions: Array = []
	var settled_positions: Array = []

	for mid in gm.positions:
		var pos = gm.positions[mid]
		if pos.get("amount", 0) == 0:
			continue
		if pos.get("is_settled", false):
			settled_positions.append({"mid": mid, "pos": pos})
		else:
			open_positions.append({"mid": mid, "pos": pos})

	if open_positions.size() > 0:
		var open_title = Label.new()
		open_title.text = "OPEN POSITIONS"
		open_title.add_theme_color_override("font_color", Color("a855f7"))
		open_title.add_theme_font_size_override("font_size", 14)
		port_list.add_child(open_title)

		for item in open_positions:
			_add_position_row(item["mid"], item["pos"], false)

	if settled_positions.size() > 0:
		var sep = Control.new()
		sep.custom_minimum_size = Vector2(0, 8)
		port_list.add_child(sep)

		var settled_title = Label.new()
		settled_title.text = "SETTLED"
		settled_title.add_theme_color_override("font_color", Color("8b8da0"))
		settled_title.add_theme_font_size_override("font_size", 14)
		port_list.add_child(settled_title)

		for item in settled_positions:
			_add_position_row(item["mid"], item["pos"], true)

	if open_positions.size() == 0 and settled_positions.size() == 0:
		var empty = Label.new()
		empty.text = "No positions yet. Swipe on markets to start trading!"
		empty.add_theme_color_override("font_color", Color("8b8da0"))
		empty.add_theme_font_size_override("font_size", 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		port_list.add_child(empty)

func _add_position_row(mid: int, pos: Dictionary, settled: bool) -> void:
	var card = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	s.border_color = Color(0.2, 0.2, 0.28, 1)
	s.set_border_width_all(1)
	s.set_corner_radius_all(10)
	s.set_content_margin_all(12)
	card.add_theme_stylebox_override("panel", s)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	card.add_child(hbox)

	var title = Label.new()
	title.text = gm.get_market_title(mid)
	title.add_theme_color_override("font_color", Color("e0e0e8"))
	title.add_theme_font_size_override("font_size", 13)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(title)

	var pick = Label.new()
	pick.text = "YES" if pos.get("is_yes", false) else "NO"
	pick.add_theme_color_override("font_color", Color("10b981") if pos.get("is_yes", false) else Color("ef4444"))
	pick.add_theme_font_size_override("font_size", 14)
	pick.custom_minimum_size.x = 30
	hbox.add_child(pick)

	var amt = Label.new()
	amt.text = "$%d" % pos.get("amount", 0)
	amt.add_theme_color_override("font_color", Color("8b8da0"))
	amt.add_theme_font_size_override("font_size", 13)
	amt.custom_minimum_size.x = 50
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(amt)

	if settled:
		var payout_lbl = Label.new()
		var payout = pos.get("payout", 0)
		if payout > 0:
			payout_lbl.text = "+$%d" % payout
			payout_lbl.add_theme_color_override("font_color", Color("10b981"))
		else:
			payout_lbl.text = "LOST"
			payout_lbl.add_theme_color_override("font_color", Color("ef4444"))
		payout_lbl.add_theme_font_size_override("font_size", 14)
		payout_lbl.custom_minimum_size.x = 60
		payout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hbox.add_child(payout_lbl)
	else:
		var market = gm.markets.get(mid, {})
		if market.get("is_resolved", false):
			var claim_btn = Button.new()
			claim_btn.text = "CLAIM"
			claim_btn.add_theme_font_size_override("font_size", 12)
			_apply_button_style(claim_btn, Color("10b981"))
			claim_btn.custom_minimum_size = Vector2(70, 30)
			var captured_mid = mid
			claim_btn.pressed.connect(func(): _claim(captured_mid))
			hbox.add_child(claim_btn)
		else:
			# Show dynamic cash-out value + CASH OUT button
			var cash_val = gm.get_cash_out_value(mid)
			var val_lbl = Label.new()
			val_lbl.text = "~$%d" % cash_val
			val_lbl.add_theme_color_override("font_color", Color("a855f7"))
			val_lbl.add_theme_font_size_override("font_size", 12)
			val_lbl.custom_minimum_size.x = 45
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			hbox.add_child(val_lbl)

			var cash_btn = Button.new()
			cash_btn.text = "CASH OUT"
			cash_btn.add_theme_font_size_override("font_size", 11)
			_apply_button_style(cash_btn, Color("f59e0b"))
			cash_btn.custom_minimum_size = Vector2(80, 28)
			var captured_mid = mid
			cash_btn.pressed.connect(func(): _cash_out(captured_mid))
			hbox.add_child(cash_btn)

	port_list.add_child(card)

func _claim(market_id: int) -> void:
	gm.claim_position(market_id)

func _cash_out(market_id: int) -> void:
	SFX.play_cash_register(self)
	gm.cash_out_early(market_id)

# === LEADERBOARD ===

func _populate_leaderboard() -> void:
	for child in lb_entries.get_children():
		child.queue_free()

	var entries = gm.all_traders.slice(0, 10)
	if entries.size() == 0:
		var empty = Label.new()
		empty.text = "No traders yet. Be the first!"
		empty.add_theme_color_override("font_color", Color("8b8da0"))
		empty.add_theme_font_size_override("font_size", 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb_entries.add_child(empty)
		return

	for i in range(entries.size()):
		var entry = entries[i]
		# Wrap in a Button for clickable spectator mode
		var row_btn = Button.new()
		row_btn.flat = true
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_btn.add_child(row)

		var rank = Label.new()
		rank.text = "#%d" % (i + 1)
		rank.add_theme_color_override("font_color", Color("a855f7") if i < 3 else Color("8b8da0"))
		rank.add_theme_font_size_override("font_size", 14)
		rank.custom_minimum_size.x = 40
		rank.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(rank)

		var addr = str(entry.get("address", "???"))
		var addr_lbl = Label.new()
		addr_lbl.text = addr.left(10) + "..." if addr.length() > 10 else addr
		addr_lbl.add_theme_color_override("font_color", Color("e0e0e8"))
		addr_lbl.add_theme_font_size_override("font_size", 13)
		addr_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		addr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(addr_lbl)

		var bal = entry.get("balance", 0)
		var bal_lbl = Label.new()
		bal_lbl.text = "$%s" % _format_number(bal)
		bal_lbl.add_theme_color_override("font_color", Color("10b981"))
		bal_lbl.add_theme_font_size_override("font_size", 14)
		bal_lbl.custom_minimum_size.x = 70
		bal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		bal_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(bal_lbl)

		var pnl = bal - 10000
		var pnl_lbl = Label.new()
		if pnl >= 0:
			pnl_lbl.text = "+$%d" % pnl
			pnl_lbl.add_theme_color_override("font_color", Color("10b981"))
		else:
			pnl_lbl.text = "-$%d" % absi(pnl)
			pnl_lbl.add_theme_color_override("font_color", Color("ef4444"))
		pnl_lbl.add_theme_font_size_override("font_size", 13)
		pnl_lbl.custom_minimum_size.x = 60
		pnl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		pnl_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(pnl_lbl)

		var played = entry.get("markets_played", 0)
		var correct = entry.get("correct_predictions", 0)
		var spy_lbl = Label.new()
		spy_lbl.text = "SPY"
		spy_lbl.add_theme_color_override("font_color", Color("a855f7"))
		spy_lbl.add_theme_font_size_override("font_size", 12)
		spy_lbl.custom_minimum_size.x = 40
		spy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		spy_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(spy_lbl)

		# Click to open spectator
		var captured_entry = entry
		row_btn.pressed.connect(func(): _show_spectator(captured_entry))

		lb_entries.add_child(row_btn)

# === ACTIONS ===

func _start() -> void:
	btn_start.disabled = true
	start_status.text = "Connecting to Starknet..."
	gm.connection.setup()
	await gm.connection.connected
	start_status.text = "Creating trader account..."
	gm.create_trader()

func _on_trader_created() -> void:
	_show_dashboard()

func _on_state(data: Dictionary) -> void:
	if dashboard_panel.visible:
		_update_dashboard()
	if swipe_panel.visible:
		var bal = gm.trader.get("balance", 10000)
		swipe_balance.text = "$%s" % _format_number(bal)

func _on_prediction_settled(market_id: int, correct: bool, payout: int) -> void:
	if not swipe_panel.visible or not _awaiting_result or _current_market_id() != market_id:
		return

	_awaiting_result = false

	# Card flip reveal
	_card_flip_reveal(func():
		if correct:
			_round_correct += 1
			card_status.text = "CORRECT! +$%s" % _format_number(payout)
			card_status.add_theme_color_override("font_color", Color("10b981"))
			# Green border flash on card
			_set_card_border_color(Color(0.06, 0.78, 0.45, 0.6))
			_flash(Color(0.06, 0.78, 0.45, 0.15))
			_spawn_float_text("+$%s" % _format_number(payout), Color("10b981"), swipe_balance)

			var streak = gm.trader.get("streak", 0)
			if streak >= 3:
				SFX.play_streak(self)
			else:
				SFX.play_correct(self)
				SFX.play_card_lock(self)
			_camera_kick(0.04)
			# Combo / Flow State
			_combo += 1
			_update_combo_display()
			if _combo >= 3 and not _in_flow_state:
				_enter_flow_state()
			# Elite card win: drop a relic
			if _current_card_type == CardType.ELITE:
				_drop_relic_reward()
		else:
			_round_wrong += 1
			var loss_text = _format_number(_swipe_wager)
			if _current_event == VolatilityEvent.FLASH_CRASH:
				loss_text = _format_number(_swipe_wager) + " (2x CRASH)"
			card_status.text = "WRONG! Lost $%s" % loss_text
			card_status.add_theme_color_override("font_color", Color("ef4444"))
			# Red border flash on card
			_set_card_border_color(Color(0.94, 0.27, 0.27, 0.6))
			_flash(Color(0.94, 0.27, 0.27, 0.15))
			_spawn_float_text("-$%s" % _format_number(_swipe_wager), Color("ef4444"), swipe_balance)
			_shake()
			SFX.play_wrong(self)
			SFX.play_heavy_impact(self)
			_camera_kick(0.06)
			# Flow State shatter on wrong
			if _in_flow_state:
				_glass_shatter()
			_combo = 0
			_update_combo_display()

		# Animate balance counter
		var old_bal = gm.trader.get("balance", 0) + ((-payout) if correct else _swipe_wager)
		var new_bal = gm.trader.get("balance", 0)
		_animate_balance(swipe_balance, old_bal, new_bal)
	)

	# Hit pause for drama
	_hit_pause(0.12)

	await get_tree().create_timer(1.5).timeout

	# Check liquidation
	var bal = gm.trader.get("balance", 0)
	if bal <= 0:
		_show_liquidated()
		return

	# Boss Defeated splash
	if correct and _current_card_type == CardType.BOSS:
		_show_boss_defeated()
		await get_tree().create_timer(1.5).timeout

	_advance_card()

func _on_tx_started(entrypoint: String) -> void:
	tx_label.text = entrypoint + "..."

func _on_tx(entrypoint: String, success: bool, tx_hash: String) -> void:
	if not success:
		if entrypoint == "create_trader":
			btn_start.disabled = false
			start_status.text = "Failed. Try again."
		elif entrypoint == "place_prediction" and swipe_panel.visible:
			card_status.text = "TX failed — try again"
			card_status.add_theme_color_override("font_color", Color("ef4444"))
			_reset_card_for_retry()
		tx_label.text = "tx failed"
		return

	if tx_hash.length() > 10:
		tx_label.text = "tx: " + tx_hash.left(10) + "..."
	else:
		tx_label.text = "confirmed"

	# For place_prediction on open market → show success and advance
	if entrypoint == "place_prediction" and swipe_panel.visible and _awaiting_result:
		var mid = _current_market_id()
		var data = GameManager.MARKET_DATA.get(mid, {})
		var on_chain = gm.markets.get(mid, {})
		var is_resolved = on_chain.get("is_resolved", data.get("pre_resolved", false))
		if not is_resolved:
			_awaiting_result = false
			card_status.text = "Position opened!"
			card_status.add_theme_color_override("font_color", Color("a855f7"))
			SFX.play_correct(self)
			await get_tree().create_timer(1.0).timeout
			_advance_card()

# === EFFECTS ===

func _flash(color: Color) -> void:
	flash_rect.color = color
	flash_rect.visible = true
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.35)
	tw.tween_callback(func(): flash_rect.visible = false)

func _shake(intensity: float = 6.0, duration: float = 0.24) -> void:
	var orig = position
	var tw = create_tween()
	var steps = int(duration / 0.04)
	for i in range(steps):
		var decay = 1.0 - (float(i) / float(steps))
		var offset = Vector2(
			randf_range(-intensity, intensity) * decay,
			randf_range(-intensity * 0.7, intensity * 0.7) * decay
		)
		tw.tween_property(self, "position", orig + offset, 0.04)
	tw.tween_property(self, "position", orig, 0.04)

# === UTILITIES ===

func _format_number(n: int) -> String:
	var s = str(absi(n))
	if s.length() <= 3:
		return s
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

func _apply_button_style(btn: Button, color: Color) -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(color, 0.08)
	s.border_color = Color(color, 0.3)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	s.set_content_margin_all(16)
	btn.add_theme_stylebox_override("normal", s)

	var sh = s.duplicate()
	sh.bg_color = Color(color, 0.15)
	sh.border_color = Color(color, 0.5)
	btn.add_theme_stylebox_override("hover", sh)

	var sp = s.duplicate()
	sp.bg_color = Color(color, 0.25)
	btn.add_theme_stylebox_override("pressed", sp)

	var sd = s.duplicate()
	sd.bg_color = Color("1a1a2e")
	sd.border_color = Color("2a2a3e")
	btn.add_theme_stylebox_override("disabled", sd)

	btn.add_theme_color_override("font_color", color.lightened(0.15))
	btn.add_theme_color_override("font_hover_color", color.lightened(0.1))
	btn.add_theme_color_override("font_pressed_color", color.lightened(0.2))
	btn.add_theme_color_override("font_disabled_color", Color("4a4a5e"))

# === OBSIDIAN UI ===

func _apply_panel_obsidian() -> void:
	var panels = [start_panel, dashboard_panel, swipe_panel, portfolio_panel,
			leaderboard_panel, liquidated_panel, round_summary_panel]
	for panel in panels:
		var s = StyleBoxFlat.new()
		s.bg_color = Color(0.04, 0.04, 0.06, 0.95)
		s.set_border_width_all(0)
		s.set_corner_radius_all(0)
		s.set_content_margin_all(20)
		panel.add_theme_stylebox_override("panel", s)

func _apply_card_glass_style() -> void:
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.06, 0.12, 0.75)
	s.border_color = Color(0.55, 0.35, 1.0, 0.5)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(20)
	# Neon glow shadow — simulates bloom around card edges
	s.shadow_color = Color(0.45, 0.25, 0.9, 0.2)
	s.shadow_size = 16
	s.shadow_offset = Vector2(0, 2)
	card_panel.add_theme_stylebox_override("panel", s)

func _set_card_border_color(color: Color) -> void:
	var s = card_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if s:
		var ns = s.duplicate() as StyleBoxFlat
		ns.border_color = color
		card_panel.add_theme_stylebox_override("panel", ns)

func _hit_pause(duration: float) -> void:
	Engine.time_scale = 0.1
	# Use process_always=true so timer runs at real time despite time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	if is_inside_tree():
		Engine.time_scale = 1.0

func _spawn_float_text(text: String, color: Color, anchor: Control) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = anchor.global_position + Vector2(0, -10)
	lbl.z_index = 100
	get_tree().root.add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 60.0, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_ease(Tween.EASE_IN).set_delay(0.2)
	tw.chain().tween_callback(lbl.queue_free)

func _card_flip_reveal(callback: Callable) -> void:
	card_container.pivot_offset = card_container.size / 2.0
	var tw = create_tween()
	tw.tween_property(card_container, "scale:x", 0.0, 0.15).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(callback)
	tw.tween_property(card_container, "scale:x", 1.0, 0.15).set_trans(Tween.TRANS_BACK)

func _animate_balance(label: Label, from: int, to: int) -> void:
	var tw = create_tween()
	var count_dict = {"val": from}
	tw.tween_method(func(v: float):
		count_dict["val"] = int(v)
		label.text = "$%s" % _format_number(int(v))
	, float(from), float(to), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

func _apply_button_juice(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(func():
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.1)
		SFX.play_hover_tick(self)
	)
	btn.mouse_exited.connect(func():
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.15)
	)
	# Press punch: instant squash → elastic bounce
	btn.button_down.connect(func():
		btn.scale = Vector2(0.9, 0.9)
	)
	btn.button_up.connect(func():
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.4)
	)

func _muffle_audio() -> void:
	var bus_idx = AudioServer.get_bus_index("Master")
	var original_vol = AudioServer.get_bus_volume_db(bus_idx)
	var tw = create_tween()
	tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(bus_idx, v),
		original_vol, original_vol - 12.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_method(func(v: float): AudioServer.set_bus_volume_db(bus_idx, v),
		original_vol - 12.0, original_vol, 0.5)

# === CAMERA KICK ===

func _camera_kick(intensity: float = 0.05) -> void:
	pivot_offset = size / 2.0
	scale = Vector2(1.0 - intensity, 1.0 - intensity)
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tw.tween_property(self, "scale", Vector2.ONE, 0.5)

# === HOLOGRAPHIC CARD TILT ===

func _update_card_tilt(delta: float) -> void:
	if not swipe_panel.visible or not card_container.visible or _dragging or _input_locked:
		# Smoothly reset tilt when not active
		if absf(card_panel.rotation) > 0.001:
			card_panel.rotation = lerpf(card_panel.rotation, 0.0, delta * 12.0)
		return

	card_panel.pivot_offset = card_panel.size / 2.0
	var card_rect = card_panel.get_global_rect()
	var card_center = card_rect.get_center()
	var mouse = get_viewport().get_mouse_position()
	var norm_x = clampf((mouse.x - card_center.x) / (card_rect.size.x * 0.5), -1.0, 1.0)

	# Smooth 3D-style tilt: max ~2.5 degrees based on mouse X offset
	var target_rot = norm_x * 0.045
	card_panel.rotation = lerpf(card_panel.rotation, target_rot, delta * 10.0)

# === POST-PROCESSING ===

func _setup_post_processing() -> void:
	# WorldEnvironment with HDR glow/bloom — works with Forward+ renderer
	var env = Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 1.2
	env.glow_strength = 1.1
	env.glow_bloom = 0.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.glow_hdr_threshold = 0.8
	env.glow_hdr_scale = 2.0
	# Enable multiple glow levels for wide soft bloom
	env.set_glow_level(0, 0.5)   # Level 1 — tight
	env.set_glow_level(1, 0.8)   # Level 2
	env.set_glow_level(3, 0.6)   # Level 4 — medium spread
	env.set_glow_level(5, 0.3)   # Level 6 — wide
	var world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

func _setup_crt_overlay() -> void:
	var crt_shader = load("res://shaders/crt_overlay.gdshader")
	if not crt_shader:
		return
	var crt_mat = ShaderMaterial.new()
	crt_mat.shader = crt_shader
	var crt_rect = ColorRect.new()
	crt_rect.material = crt_mat
	crt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crt_rect.color = Color(1, 1, 1, 1)
	add_child(crt_rect)

# === RELIC BAR ===

func _build_relic_bar() -> void:
	# Insert relic buttons below the wager bar inside SwipeVBox
	_relic_bar = HBoxContainer.new()
	_relic_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_relic_bar.add_theme_constant_override("separation", 8)
	_relic_bar.visible = false

	_btn_leverage = Button.new()
	_btn_leverage.text = "3x LEVERAGE (0)"
	_btn_leverage.add_theme_font_size_override("font_size", 12)
	_apply_button_style(_btn_leverage, Color("ef4444"))
	_btn_leverage.pressed.connect(func(): _activate_relic("leverage_tokens"))
	_relic_bar.add_child(_btn_leverage)

	_btn_stop_loss = Button.new()
	_btn_stop_loss.text = "STOP LOSS (0)"
	_btn_stop_loss.add_theme_font_size_override("font_size", 12)
	_apply_button_style(_btn_stop_loss, Color("10b981"))
	_btn_stop_loss.pressed.connect(func(): _activate_relic("stop_loss"))
	_relic_bar.add_child(_btn_stop_loss)

	_btn_insider = Button.new()
	_btn_insider.text = "INSIDER (0)"
	_btn_insider.add_theme_font_size_override("font_size", 12)
	_apply_button_style(_btn_insider, Color("a855f7"))
	_btn_insider.pressed.connect(func(): _activate_relic("insider_info"))
	_relic_bar.add_child(_btn_insider)

	# Add after wager_bar in the same parent
	wager_bar.get_parent().add_child(_relic_bar)
	wager_bar.get_parent().move_child(_relic_bar, wager_bar.get_index() + 1)

	# Apply hover juice to relic buttons
	for btn in [_btn_leverage, _btn_stop_loss, _btn_insider]:
		_apply_button_juice(btn)

func _update_relic_bar() -> void:
	if not _relic_bar:
		return
	var lev = gm.relics.get("leverage_tokens", 0)
	var sl = gm.relics.get("stop_loss", 0)
	var ins = gm.relics.get("insider_info", 0)
	_btn_leverage.text = "3x LEVERAGE (%d)" % lev
	_btn_leverage.disabled = lev <= 0
	_btn_stop_loss.text = "STOP LOSS (%d)" % sl
	_btn_stop_loss.disabled = sl <= 0
	_btn_insider.text = "INSIDER (%d)" % ins
	_btn_insider.disabled = ins <= 0

	# Highlight active relic
	if _active_relic == "leverage_tokens":
		_btn_leverage.text = ">> 3x LEVERAGE <<"
	elif _active_relic == "stop_loss":
		_btn_stop_loss.text = ">> STOP LOSS <<"
	elif _active_relic == "insider_info":
		_btn_insider.text = ">> INSIDER <<"

func _activate_relic(relic_key: String) -> void:
	if gm.relics.get(relic_key, 0) <= 0:
		return
	# Toggle: tap again to deactivate
	if _active_relic == relic_key:
		_active_relic = ""
	else:
		_active_relic = relic_key
	SFX.play_card_lock(self)
	_update_relic_bar()

	# If insider, re-populate card to show answer
	if _active_relic == "insider_info":
		var mid = _current_market_id()
		var data = GameManager.MARKET_DATA.get(mid, {})
		if data.get("pre_resolved", false):
			var answer = "YES" if data.get("outcome", false) else "NO"
			card_status.text = "INSIDER: Answer is %s" % answer
			card_status.add_theme_color_override("font_color", Color("a855f7"))

# === DARK POOL SHOP ===

func _build_shop_panel() -> void:
	_shop_panel = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.04, 0.06, 0.95)
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(24)
	_shop_panel.add_theme_stylebox_override("panel", s)
	_shop_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shop_panel.visible = false

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_shop_panel.add_child(vbox)

	var title = Label.new()
	title.text = "DARK POOL"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("a855f7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "Spend your gains for an edge... or hoard for the leaderboard."
	subtitle.add_theme_font_size_override("font_size", 14)
	subtitle.add_theme_color_override("font_color", Color("8b8da0"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(subtitle)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Shop items
	var items = [
		{"key": "leverage_tokens", "name": "3x LEVERAGE", "cost": 1500, "desc": "Triple your next wager (3x risk, 3x reward)", "color": Color("ef4444"), "type": 0},
		{"key": "stop_loss", "name": "STOP LOSS", "cost": 1000, "desc": "Cap next wager at $100 (safety net)", "color": Color("10b981"), "type": 1},
		{"key": "insider_info", "name": "INSIDER INFO", "cost": 2000, "desc": "Reveal the correct answer before you swipe", "color": Color("a855f7"), "type": 2},
	]

	for item in items:
		var card = PanelContainer.new()
		var cs = StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.08, 0.14, 0.7)
		cs.border_color = Color(item["color"], 0.3)
		cs.set_border_width_all(1)
		cs.set_corner_radius_all(12)
		cs.set_content_margin_all(16)
		card.add_theme_stylebox_override("panel", cs)

		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 12)
		card.add_child(hbox)

		var info_vbox = VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lbl = Label.new()
		name_lbl.text = item["name"]
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override("font_color", item["color"])
		info_vbox.add_child(name_lbl)
		var desc_lbl = Label.new()
		desc_lbl.text = item["desc"]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color("8b8da0"))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info_vbox.add_child(desc_lbl)
		hbox.add_child(info_vbox)

		var buy_btn = Button.new()
		buy_btn.text = "$%d" % item["cost"]
		buy_btn.add_theme_font_size_override("font_size", 16)
		buy_btn.custom_minimum_size = Vector2(90, 40)
		_apply_button_style(buy_btn, item["color"])
		_apply_button_juice(buy_btn)
		var relic_type = item["type"]
		var relic_key = item["key"]
		buy_btn.pressed.connect(func():
			_buy_shop_item(relic_key, relic_type)
		)
		buy_btn.name = "ShopBtn_" + item["key"]
		hbox.add_child(buy_btn)

		vbox.add_child(card)

	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer2)

	# Balance display
	var bal_lbl = Label.new()
	bal_lbl.name = "ShopBalance"
	bal_lbl.add_theme_font_size_override("font_size", 18)
	bal_lbl.add_theme_color_override("font_color", Color("e0e0f0"))
	bal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(bal_lbl)

	# Continue button
	_shop_continue_btn = Button.new()
	_shop_continue_btn.text = "ENTER THE ARENA"
	_shop_continue_btn.add_theme_font_size_override("font_size", 20)
	_apply_button_style(_shop_continue_btn, Color("a855f7"))
	_apply_button_juice(_shop_continue_btn)
	_shop_continue_btn.pressed.connect(func():
		if _shop_from_dashboard:
			_show_swipe()
		else:
			_hide_all()
			swipe_panel.visible = true
			_start_round()
	)
	vbox.add_child(_shop_continue_btn)

	add_child(_shop_panel)

func _show_shop() -> void:
	_shop_from_dashboard = false
	_hide_all()
	_shop_panel.visible = true
	_update_shop_ui()
	if _shop_continue_btn:
		_shop_continue_btn.text = "ENTER THE ARENA"
	_shop_panel.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_shop_panel, "modulate:a", 1.0, 0.4)
	SFX.play_round_complete(self)

func _show_shop_from_dashboard() -> void:
	_shop_from_dashboard = true
	_hide_all()
	_shop_panel.visible = true
	_update_shop_ui()
	if _shop_continue_btn:
		_shop_continue_btn.text = "START TRADING"
	_shop_panel.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_shop_panel, "modulate:a", 1.0, 0.4)
	SFX.play_round_complete(self)

func _update_shop_ui() -> void:
	if not _shop_panel:
		return
	var bal = gm.trader.get("balance", 0)
	# Update balance label
	var bal_lbl = _shop_panel.find_child("ShopBalance", true, false) as Label
	if bal_lbl:
		bal_lbl.text = "Balance: $%s" % _format_number(bal)

	# Update buy button states
	for key in ["leverage_tokens", "stop_loss", "insider_info"]:
		var btn = _shop_panel.find_child("ShopBtn_" + key, true, false) as Button
		if btn:
			var cost = GameManager.RELIC_COSTS.get(key, 9999)
			btn.disabled = bal < cost
			var count = gm.relics.get(key, 0)
			if count > 0:
				btn.text = "$%d (%d)" % [cost, count]
			else:
				btn.text = "$%d" % cost

func _buy_shop_item(relic_key: String, relic_type: int) -> void:
	if gm.buy_relic_local(relic_key):
		SFX.play_correct(self)
		_camera_kick(0.03)
		_flash(Color(0.4, 0.3, 0.8, 0.15))
		_update_shop_ui()
		# Also send to chain (fire and forget)
		gm.buy_relic(relic_type)
	else:
		SFX.play_wrong(self)
		_shake(4.0, 0.15)

# === VOLATILITY EVENTS ===

func _build_event_label() -> void:
	_event_label = Label.new()
	_event_label.add_theme_font_size_override("font_size", 14)
	_event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_event_label.visible = false
	# Insert above round_info in the same parent
	round_info.get_parent().add_child(_event_label)
	round_info.get_parent().move_child(_event_label, round_info.get_index())

func _roll_volatility_event() -> void:
	_current_event = VolatilityEvent.NONE
	if _event_label:
		_event_label.visible = false

	# Only trigger from round 2+
	if _round_number < 2:
		return

	var roll = randf()
	if roll < 0.40:
		_current_event = VolatilityEvent.NONE
	elif roll < 0.60:
		_current_event = VolatilityEvent.FLASH_CRASH
	elif roll < 0.80:
		_current_event = VolatilityEvent.BULL_RUN
	else:
		_current_event = VolatilityEvent.BEAR_TRAP

	if _current_event == VolatilityEvent.NONE:
		return

	# Show event label
	_event_label.visible = true
	match _current_event:
		VolatilityEvent.FLASH_CRASH:
			_event_label.text = "FLASH CRASH — Losses are 2x this round!"
			_event_label.add_theme_color_override("font_color", Color("ef4444"))
		VolatilityEvent.BULL_RUN:
			_event_label.text = "BULL RUN — ALL IN on every trade!"
			_event_label.add_theme_color_override("font_color", Color("10b981"))
		VolatilityEvent.BEAR_TRAP:
			_event_label.text = "BEAR TRAP — Only 10 seconds per card!"
			_event_label.add_theme_color_override("font_color", Color("f59e0b"))

	# Dramatic popup animation
	_show_volatility_popup()

func _show_volatility_popup() -> void:
	var popup = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.02, 0.04, 0.92)
	s.border_color = Color("a855f7")
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(32)
	popup.add_theme_stylebox_override("panel", s)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.z_index = 200

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	var icon_lbl = Label.new()
	icon_lbl.add_theme_font_size_override("font_size", 36)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var desc_lbl = Label.new()
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color("8b8da0"))
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	match _current_event:
		VolatilityEvent.FLASH_CRASH:
			icon_lbl.text = "FLASH CRASH"
			icon_lbl.add_theme_color_override("font_color", Color("ef4444"))
			title_lbl.text = "MARKETS ARE CRASHING"
			title_lbl.add_theme_color_override("font_color", Color("ef4444"))
			desc_lbl.text = "All losses are doubled this round"
			s.border_color = Color("ef4444")
		VolatilityEvent.BULL_RUN:
			icon_lbl.text = "BULL RUN"
			icon_lbl.add_theme_color_override("font_color", Color("10b981"))
			title_lbl.text = "FORCED ALL IN"
			title_lbl.add_theme_color_override("font_color", Color("10b981"))
			desc_lbl.text = "Your entire balance on every trade"
			s.border_color = Color("10b981")
		VolatilityEvent.BEAR_TRAP:
			icon_lbl.text = "BEAR TRAP"
			icon_lbl.add_theme_color_override("font_color", Color("f59e0b"))
			title_lbl.text = "TIME IS SHORT"
			title_lbl.add_theme_color_override("font_color", Color("f59e0b"))
			desc_lbl.text = "Only 10 seconds per card"
			s.border_color = Color("f59e0b")

	vbox.add_child(icon_lbl)
	vbox.add_child(title_lbl)
	vbox.add_child(desc_lbl)
	add_child(popup)

	# Scale-in animation
	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2(0.3, 0.3)
	popup.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(popup, "scale", Vector2.ONE, 0.4)
	tw.parallel().tween_property(popup, "modulate:a", 1.0, 0.2)
	# Hold, then fade out
	tw.tween_interval(1.5)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw.tween_callback(popup.queue_free)

	# Screen effects
	_shake(8.0, 0.3)
	_camera_kick(0.06)
	SFX.play_heavy_impact(self)
	_flash(Color(0.4, 0.2, 0.8, 0.2))

# === WORLD BOSS ===

func _create_world_boss_banner() -> PanelContainer:
	var banner = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.06, 0.04, 0.12, 0.9)
	s.border_color = Color(0.6, 0.3, 1.0, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(14)
	s.set_content_margin_all(14)
	s.shadow_color = Color(0.5, 0.2, 1.0, 0.15)
	s.shadow_size = 12
	banner.add_theme_stylebox_override("panel", s)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_child(hbox)

	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title = Label.new()
	title.text = "WORLD BOSS"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("a855f7"))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(title)
	var desc = Label.new()
	desc.text = GameManager.WORLD_BOSS_TITLE
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color("8b8da0"))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(desc)
	var live = Label.new()
	live.text = "LIVE STATE SYNC: ACTIVE"
	live.add_theme_font_size_override("font_size", 10)
	live.add_theme_color_override("font_color", Color("10b981"))
	live.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(live)
	hbox.add_child(info)

	var enter_btn = Button.new()
	enter_btn.text = "ENTER"
	enter_btn.add_theme_font_size_override("font_size", 14)
	enter_btn.custom_minimum_size = Vector2(70, 36)
	_apply_button_style(enter_btn, Color("a855f7"))
	_apply_button_juice(enter_btn)
	enter_btn.pressed.connect(func(): _show_world_boss())
	hbox.add_child(enter_btn)

	return banner

func _build_world_boss_panel() -> void:
	_world_boss_panel = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.03, 0.06, 0.97)
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(24)
	_world_boss_panel.add_theme_stylebox_override("panel", s)
	_world_boss_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world_boss_panel.visible = false

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	_world_boss_panel.add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(back_btn, Color("8b8da0"))
	_apply_button_juice(back_btn)
	back_btn.pressed.connect(_show_dashboard)
	header.add_child(back_btn)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_wb_sync_label = Label.new()
	_wb_sync_label.text = "TORII LIVE SYNC: ACTIVE"
	_wb_sync_label.add_theme_font_size_override("font_size", 11)
	_wb_sync_label.add_theme_color_override("font_color", Color("10b981"))
	header.add_child(_wb_sync_label)
	vbox.add_child(header)

	# Title
	var title = Label.new()
	title.text = "WORLD BOSS"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("a855f7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var question = Label.new()
	question.text = GameManager.WORLD_BOSS_TITLE
	question.add_theme_font_size_override("font_size", 16)
	question.add_theme_color_override("font_color", Color("e0e0f0"))
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(question)

	# Tug-of-war bar
	var bar_container = PanelContainer.new()
	var bcs = StyleBoxFlat.new()
	bcs.bg_color = Color(0.08, 0.08, 0.12, 0.8)
	bcs.set_corner_radius_all(10)
	bcs.set_content_margin_all(4)
	bar_container.add_theme_stylebox_override("panel", bcs)
	bar_container.custom_minimum_size = Vector2(0, 40)

	var bar_hbox = HBoxContainer.new()
	bar_hbox.add_theme_constant_override("separation", 0)
	bar_container.add_child(bar_hbox)

	_wb_yes_bar = ColorRect.new()
	_wb_yes_bar.color = Color("10b981")
	_wb_yes_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wb_yes_bar.size_flags_stretch_ratio = 1.0
	_wb_yes_bar.custom_minimum_size = Vector2(10, 32)
	bar_hbox.add_child(_wb_yes_bar)

	_wb_no_bar = ColorRect.new()
	_wb_no_bar.color = Color("ef4444")
	_wb_no_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_wb_no_bar.size_flags_stretch_ratio = 1.0
	_wb_no_bar.custom_minimum_size = Vector2(10, 32)
	bar_hbox.add_child(_wb_no_bar)

	vbox.add_child(bar_container)

	_wb_ratio_label = Label.new()
	_wb_ratio_label.text = "YES: 0 | NO: 0"
	_wb_ratio_label.add_theme_font_size_override("font_size", 14)
	_wb_ratio_label.add_theme_color_override("font_color", Color("e0e0f0"))
	_wb_ratio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_wb_ratio_label)

	# Bet buttons
	# Your bet status
	_wb_your_bet_label = Label.new()
	_wb_your_bet_label.add_theme_font_size_override("font_size", 16)
	_wb_your_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wb_your_bet_label.visible = false
	vbox.add_child(_wb_your_bet_label)

	var bet_row = HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 16)
	_wb_bet_yes_btn = Button.new()
	_wb_bet_yes_btn.text = "BET YES ($500)"
	_wb_bet_yes_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_style(_wb_bet_yes_btn, Color("10b981"))
	_apply_button_juice(_wb_bet_yes_btn)
	_wb_bet_yes_btn.pressed.connect(func(): _bet_world_boss(true))
	bet_row.add_child(_wb_bet_yes_btn)
	_wb_bet_no_btn = Button.new()
	_wb_bet_no_btn.text = "BET NO ($500)"
	_wb_bet_no_btn.add_theme_font_size_override("font_size", 18)
	_apply_button_style(_wb_bet_no_btn, Color("ef4444"))
	_apply_button_juice(_wb_bet_no_btn)
	_wb_bet_no_btn.pressed.connect(func(): _bet_world_boss(false))
	bet_row.add_child(_wb_bet_no_btn)
	vbox.add_child(bet_row)

	# Live feed header
	var feed_title = Label.new()
	feed_title.text = "LIVE FEED — Last 5 Bettors (Torii Indexed)"
	feed_title.add_theme_font_size_override("font_size", 12)
	feed_title.add_theme_color_override("font_color", Color("a855f7"))
	feed_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(feed_title)

	# Scrolling feed
	_wb_feed = VBoxContainer.new()
	_wb_feed.add_theme_constant_override("separation", 4)
	vbox.add_child(_wb_feed)

	# Dojo tech label
	var tech = Label.new()
	tech.text = "Powered by Dojo Torii Indexer + Cartridge Controller"
	tech.add_theme_font_size_override("font_size", 10)
	tech.add_theme_color_override("font_color", Color("4a4a5e"))
	tech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tech)

	add_child(_world_boss_panel)

func _show_world_boss() -> void:
	_hide_all()
	_world_boss_panel.visible = true
	_update_world_boss_ui()

func _update_world_boss_ui() -> void:
	if not _world_boss_panel:
		return
	var wb = gm.world_boss
	var ty = wb.get("total_yes", 0)
	var tn = wb.get("total_no", 0)
	var tya = wb.get("total_yes_amount", 0)
	var tna = wb.get("total_no_amount", 0)
	var total = ty + tn

	# Update tug-of-war bar ratios
	if total > 0:
		_wb_yes_bar.size_flags_stretch_ratio = maxf(float(ty) / float(total), 0.05)
		_wb_no_bar.size_flags_stretch_ratio = maxf(float(tn) / float(total), 0.05)
	else:
		_wb_yes_bar.size_flags_stretch_ratio = 0.5
		_wb_no_bar.size_flags_stretch_ratio = 0.5

	_wb_ratio_label.text = "YES: %d ($%s) | NO: %d ($%s)" % [ty, _format_number(tya), tn, _format_number(tna)]

	# Update live feed
	for child in _wb_feed.get_children():
		child.queue_free()
	var recent: Array = wb.get("recent", [])
	if recent.size() == 0:
		var empty = Label.new()
		empty.text = "No bets yet. Be the first!"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", Color("8b8da0"))
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_wb_feed.add_child(empty)
	else:
		for addr in recent:
			var lbl = Label.new()
			var short = addr.left(14) + "..." if addr.length() > 14 else addr
			lbl.text = "> %s placed a bet" % short
			lbl.add_theme_font_size_override("font_size", 11)
			lbl.add_theme_color_override("font_color", Color("38bdf8"))
			_wb_feed.add_child(lbl)

	# Maintain bet state on refresh
	if _wb_has_bet:
		if _wb_bet_yes_btn:
			_wb_bet_yes_btn.disabled = true
		if _wb_bet_no_btn:
			_wb_bet_no_btn.disabled = true
		if _wb_your_bet_label:
			_wb_your_bet_label.visible = true

	# Pulse sync label
	if _wb_sync_label:
		_wb_sync_label.modulate.a = 0.5
		var tw = create_tween()
		tw.tween_property(_wb_sync_label, "modulate:a", 1.0, 0.3)

func _on_world_boss_updated(_boss: Dictionary) -> void:
	if _world_boss_panel and _world_boss_panel.visible:
		_update_world_boss_ui()

func _bet_world_boss(is_yes: bool) -> void:
	if _wb_has_bet:
		return
	var bal = gm.trader.get("balance", 0)
	var wager = mini(500, bal)
	if wager <= 0:
		SFX.play_wrong(self)
		return
	_wb_has_bet = true
	_wb_bet_side = "YES" if is_yes else "NO"
	gm.bet_world_boss(is_yes, wager)
	SFX.play_card_lock(self)
	_camera_kick(0.03)
	_flash(Color(0.4, 0.3, 0.8, 0.15))

	# Show feedback
	if _wb_your_bet_label:
		var color = Color("10b981") if is_yes else Color("ef4444")
		_wb_your_bet_label.text = "You bet %s ($%s) — Awaiting resolution" % [_wb_bet_side, _format_number(wager)]
		_wb_your_bet_label.add_theme_color_override("font_color", color)
		_wb_your_bet_label.visible = true
	if _wb_bet_yes_btn:
		_wb_bet_yes_btn.disabled = true
	if _wb_bet_no_btn:
		_wb_bet_no_btn.disabled = true
	_spawn_float_text("BET PLACED!", Color("a855f7"), _wb_ratio_label)

# === SPECTATOR MODE (Degen Spectator) ===

func _build_spectator_panel() -> void:
	_spectator_panel = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.03, 0.03, 0.06, 0.97)
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(24)
	_spectator_panel.add_theme_stylebox_override("panel", s)
	_spectator_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_spectator_panel.visible = false
	_spectator_panel.z_index = 150
	add_child(_spectator_panel)

func _show_spectator(trader_entry: Dictionary) -> void:
	# Clear old content
	for child in _spectator_panel.get_children():
		child.queue_free()

	var addr = str(trader_entry.get("address", ""))

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	_spectator_panel.add_child(vbox)

	# Header
	var header = HBoxContainer.new()
	var back_btn = Button.new()
	back_btn.text = "BACK"
	back_btn.add_theme_font_size_override("font_size", 14)
	_apply_button_style(back_btn, Color("8b8da0"))
	_apply_button_juice(back_btn)
	back_btn.pressed.connect(func():
		_spectator_panel.visible = false
		leaderboard_panel.visible = true
	)
	header.add_child(back_btn)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var torii_lbl = Label.new()
	torii_lbl.text = "TORII QUERY: LIVE"
	torii_lbl.add_theme_font_size_override("font_size", 11)
	torii_lbl.add_theme_color_override("font_color", Color("10b981"))
	header.add_child(torii_lbl)
	vbox.add_child(header)

	# Player info
	var title = Label.new()
	title.text = "DEGEN SPECTATOR"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("a855f7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var short_addr = addr.left(16) + "..." if addr.length() > 16 else addr
	var addr_label = Label.new()
	addr_label.text = short_addr
	addr_label.add_theme_font_size_override("font_size", 13)
	addr_label.add_theme_color_override("font_color", Color("38bdf8"))
	addr_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(addr_label)

	# Stats
	var bal = trader_entry.get("balance", 0)
	var wagered = trader_entry.get("total_wagered", 0)
	var won = trader_entry.get("total_won", 0)
	var lost = trader_entry.get("total_lost", 0)
	var played = trader_entry.get("markets_played", 0)
	var correct = trader_entry.get("correct_predictions", 0)
	var streak = trader_entry.get("streak", 0)

	var stats_text = "Balance: $%s | Wagered: $%s\nWon: $%s | Lost: $%s\n%d Markets | %d%% Accuracy | %dx Streak" % [
		_format_number(bal), _format_number(wagered),
		_format_number(won), _format_number(lost),
		played, ((correct * 100) / played) if played > 0 else 0, streak
	]
	var stats = Label.new()
	stats.text = stats_text
	stats.add_theme_font_size_override("font_size", 14)
	stats.add_theme_color_override("font_color", Color("e0e0f0"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	# Active positions
	var pos_title = Label.new()
	pos_title.text = "ACTIVE POSITIONS"
	pos_title.add_theme_font_size_override("font_size", 14)
	pos_title.add_theme_color_override("font_color", Color("a855f7"))
	vbox.add_child(pos_title)

	var player_positions = gm.get_positions_for_player(addr)
	var open_count = 0
	for pos in player_positions:
		if pos.get("amount", 0) <= 0:
			continue
		var mid = pos.get("market_id", 0)
		var is_settled = pos.get("is_settled", false)
		if is_settled:
			continue
		open_count += 1

		var pos_card = PanelContainer.new()
		var pcs = StyleBoxFlat.new()
		pcs.bg_color = Color(0.08, 0.08, 0.14, 0.7)
		pcs.border_color = Color(0.3, 0.3, 0.45, 0.5)
		pcs.set_border_width_all(1)
		pcs.set_corner_radius_all(10)
		pcs.set_content_margin_all(10)
		pos_card.add_theme_stylebox_override("panel", pcs)

		var pos_hbox = HBoxContainer.new()
		pos_hbox.add_theme_constant_override("separation", 8)
		pos_card.add_child(pos_hbox)

		var pos_title_lbl = Label.new()
		pos_title_lbl.text = gm.get_market_title(mid)
		pos_title_lbl.add_theme_font_size_override("font_size", 12)
		pos_title_lbl.add_theme_color_override("font_color", Color("e0e0e8"))
		pos_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pos_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pos_hbox.add_child(pos_title_lbl)

		var pick_lbl = Label.new()
		var is_yes = pos.get("is_yes", false)
		pick_lbl.text = "YES" if is_yes else "NO"
		pick_lbl.add_theme_color_override("font_color", Color("10b981") if is_yes else Color("ef4444"))
		pick_lbl.add_theme_font_size_override("font_size", 13)
		pos_hbox.add_child(pick_lbl)

		var amt_lbl = Label.new()
		amt_lbl.text = "$%d" % pos.get("amount", 0)
		amt_lbl.add_theme_color_override("font_color", Color("8b8da0"))
		amt_lbl.add_theme_font_size_override("font_size", 12)
		pos_hbox.add_child(amt_lbl)

		# COPY BET — Technical flex: session key makes this instant
		# "Cartridge Session Keys enable copy-trading with zero approval popups"
		var copy_btn = Button.new()
		copy_btn.text = "COPY"
		copy_btn.add_theme_font_size_override("font_size", 11)
		copy_btn.custom_minimum_size = Vector2(55, 28)
		_apply_button_style(copy_btn, Color("a855f7"))
		var captured_mid = mid
		var captured_yes = is_yes
		copy_btn.pressed.connect(func():
			_copy_bet(captured_mid, captured_yes)
		)
		pos_hbox.add_child(copy_btn)

		vbox.add_child(pos_card)

	if open_count == 0:
		var no_pos = Label.new()
		no_pos.text = "No open positions"
		no_pos.add_theme_font_size_override("font_size", 12)
		no_pos.add_theme_color_override("font_color", Color("8b8da0"))
		no_pos.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(no_pos)

	# Tech flex label
	var tech = Label.new()
	tech.text = "Copy-trading via Cartridge Session Key — zero popups"
	tech.add_theme_font_size_override("font_size", 10)
	tech.add_theme_color_override("font_color", Color("4a4a5e"))
	tech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(tech)

	_hide_all()
	_spectator_panel.visible = true
	SFX.play_hover_tick(self)

func _copy_bet(market_id: int, is_yes: bool) -> void:
	# Copy another player's bet using our own session key — instant, no popup
	var bal = gm.trader.get("balance", 0)
	var wager = mini(500, bal)
	if wager <= 0:
		SFX.play_wrong(self)
		return
	# Check we don't already have a position
	if gm.positions.has(market_id) and gm.positions[market_id].get("amount", 0) > 0:
		SFX.play_wrong(self)
		return
	gm.place_prediction(market_id, is_yes, wager)
	SFX.play_correct(self)
	_camera_kick(0.03)
	_flash(Color(0.4, 0.3, 0.8, 0.15))
	_spawn_float_text("COPIED!", Color("a855f7"), _spectator_panel)

# === RAPID FIRE (Session Key Flex) ===

func _build_session_key_label() -> void:
	# "SESSION KEY AUTO-SIGN" flash label — visible during rapid fire
	# Place next to timer_label in the swipe header row
	_session_key_label = Label.new()
	_session_key_label.text = "SESSION KEY AUTO-SIGN"
	_session_key_label.add_theme_font_size_override("font_size", 10)
	_session_key_label.add_theme_color_override("font_color", Color("10b981"))
	_session_key_label.visible = false
	# Insert into same parent as timer_label (SwipeHeader row)
	timer_label.get_parent().add_child(_session_key_label)

func _show_rapid_fire_popup() -> void:
	var popup = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.02, 0.04, 0.92)
	s.border_color = Color("10b981")
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(32)
	popup.add_theme_stylebox_override("panel", s)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.z_index = 200

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	var icon = Label.new()
	icon.text = "RAPID FIRE"
	icon.add_theme_font_size_override("font_size", 36)
	icon.add_theme_color_override("font_color", Color("10b981"))
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon)

	var title = Label.new()
	title.text = "5 CARDS — 3 SECONDS EACH"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("38bdf8"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# The hackathon narrative — visible to judges
	var flex = Label.new()
	flex.text = "Only possible with Cartridge Session Keys.\nStandard wallets would popup 5 times."
	flex.add_theme_font_size_override("font_size", 12)
	flex.add_theme_color_override("font_color", Color("8b8da0"))
	flex.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(flex)

	add_child(popup)

	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2(0.3, 0.3)
	popup.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(popup, "scale", Vector2.ONE, 0.4)
	tw.parallel().tween_property(popup, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.0)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw.tween_callback(popup.queue_free)

	_shake(6.0, 0.25)
	_camera_kick(0.04)
	SFX.play_streak(self)

# === COMBO / FLOW STATE ===

func _build_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.add_theme_font_size_override("font_size", 20)
	_combo_label.add_theme_color_override("font_color", Color("a855f7"))
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_label.visible = false
	# Insert after round_info
	round_info.get_parent().add_child(_combo_label)
	round_info.get_parent().move_child(_combo_label, round_info.get_index() + 1)

func _update_combo_display() -> void:
	if not _combo_label:
		return
	if _combo >= 2:
		_combo_label.visible = true
		if _in_flow_state:
			_combo_label.text = "FLOW STATE x%d (+10%%)" % _combo
			_combo_label.add_theme_color_override("font_color", Color("38bdf8"))
		else:
			_combo_label.text = "COMBO x%d" % _combo
			_combo_label.add_theme_color_override("font_color", Color("a855f7"))
		# Punch animation
		_combo_label.pivot_offset = _combo_label.size / 2.0
		_combo_label.scale = Vector2(1.4, 1.4)
		var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(_combo_label, "scale", Vector2.ONE, 0.3)
	else:
		_combo_label.visible = false

func _enter_flow_state() -> void:
	_in_flow_state = true
	_flash(Color(0.23, 0.74, 0.97, 0.2))
	SFX.play_streak(self)
	_spawn_float_text("FLOW STATE!", Color("38bdf8"), round_info)
	# Camera zoom in
	pivot_offset = size / 2.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(self, "scale", Vector2(1.03, 1.03), 0.5)
	# Speed up background shader
	if background and background.material:
		var mat = background.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("time_speed", 3.0)

func _glass_shatter() -> void:
	# White flash, heavy shake, dead silence, camera snap, shader goes dark
	_flash(Color(1.0, 1.0, 1.0, 0.5))
	_shake(16.0, 0.5)
	_camera_kick(0.1)
	SFX.play_heavy_impact(self)
	_muffle_audio()
	_spawn_float_text("SHATTERED!", Color("ef4444"), round_info)
	# Camera snap back to normal
	pivot_offset = size / 2.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(self, "scale", Vector2.ONE, 0.3)
	# Shader goes dark briefly
	if background and background.material:
		var mat = background.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("time_speed", 0.2)
			var stw = create_tween()
			stw.tween_interval(1.5)
			stw.tween_callback(func(): mat.set_shader_parameter("time_speed", 1.0))
	_in_flow_state = false
	_combo = 0
	_update_combo_display()

# === EVENT NODES ===

func _build_event_node_panel() -> void:
	_event_panel = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.04, 0.03, 0.08, 0.97)
	s.border_color = Color(0.6, 0.3, 1.0, 0.5)
	s.set_border_width_all(2)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(24)
	s.shadow_color = Color(0.5, 0.2, 1.0, 0.15)
	s.shadow_size = 12
	_event_panel.add_theme_stylebox_override("panel", s)
	_event_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_event_panel.visible = false
	_event_panel.z_index = 100
	add_child(_event_panel)

func _show_event_node() -> void:
	# Clear old content
	for child in _event_panel.get_children():
		child.queue_free()

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	_event_panel.add_child(vbox)

	var title = Label.new()
	title.text = "AN ALTAR TO THE DOJO GODS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("a855f7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "You stumble upon a mysterious altar pulsing with onchain energy.\nThe Dojo Gods demand a tribute... or a prayer."
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color("e0e0f0"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(spacer)

	# Choice 1: Sacrifice $500 for a relic
	var btn1 = Button.new()
	btn1.text = "SACRIFICE $500 — Receive a random relic"
	btn1.add_theme_font_size_override("font_size", 16)
	_apply_button_style(btn1, Color("a855f7"))
	_apply_button_juice(btn1)
	btn1.pressed.connect(func(): _event_sacrifice())
	vbox.add_child(btn1)

	# Choice 2: Pray — 50/50 gamble
	var btn2 = Button.new()
	btn2.text = "PRAY — 50/50: Win $1,000 or lose $500"
	btn2.add_theme_font_size_override("font_size", 16)
	_apply_button_style(btn2, Color("f59e0b"))
	_apply_button_juice(btn2)
	btn2.pressed.connect(func(): _event_pray())
	vbox.add_child(btn2)

	# Choice 3: Walk away
	var btn3 = Button.new()
	btn3.text = "WALK AWAY — Nothing happens"
	btn3.add_theme_font_size_override("font_size", 16)
	_apply_button_style(btn3, Color("8b8da0"))
	_apply_button_juice(btn3)
	btn3.pressed.connect(func(): _event_walk_away())
	vbox.add_child(btn3)

	# Balance display
	var bal_lbl = Label.new()
	bal_lbl.text = "Balance: $%s" % _format_number(gm.trader.get("balance", 0))
	bal_lbl.add_theme_font_size_override("font_size", 14)
	bal_lbl.add_theme_color_override("font_color", Color("8b8da0"))
	bal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(bal_lbl)

	_hide_all()
	swipe_panel.visible = true
	_event_panel.visible = true
	card_container.visible = false
	wager_bar.visible = false
	if _relic_bar:
		_relic_bar.visible = false

	# Dramatic entrance
	_event_panel.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(_event_panel, "modulate:a", 1.0, 0.5)
	SFX.play_heavy_impact(self)
	_camera_kick(0.04)

func _event_sacrifice() -> void:
	var bal = gm.trader.get("balance", 0)
	if bal < 500:
		SFX.play_wrong(self)
		_spawn_float_text("Not enough!", Color("ef4444"), _event_panel)
		return
	# Deduct $500 locally and give random relic
	gm.trader["balance"] = bal - 500
	var relic_keys = ["leverage_tokens", "stop_loss", "insider_info"]
	var chosen = relic_keys[randi() % relic_keys.size()]
	gm.relics[chosen] = gm.relics.get(chosen, 0) + 1
	# Buy on chain (fire and forget)
	var relic_type = 0 if chosen == "leverage_tokens" else (1 if chosen == "stop_loss" else 2)
	gm.buy_relic(relic_type)
	SFX.play_streak(self)
	_flash(Color(0.4, 0.3, 0.8, 0.2))
	var name_map = {"leverage_tokens": "3x LEVERAGE", "stop_loss": "STOP LOSS", "insider_info": "INSIDER INFO"}
	_spawn_float_text("Got %s!" % name_map[chosen], Color("a855f7"), _event_panel)
	await get_tree().create_timer(1.2).timeout
	_close_event_and_advance()

func _event_pray() -> void:
	var bal = gm.trader.get("balance", 0)
	if bal < 500:
		SFX.play_wrong(self)
		_spawn_float_text("Not enough!", Color("ef4444"), _event_panel)
		return
	var won = randf() < 0.5
	if won:
		gm.trader["balance"] = bal + 1000
		SFX.play_streak(self)
		_flash(Color(0.06, 0.78, 0.45, 0.2))
		_spawn_float_text("+$1,000!", Color("10b981"), _event_panel)
	else:
		gm.trader["balance"] = bal - 500
		SFX.play_wrong(self)
		_flash(Color(0.94, 0.27, 0.27, 0.2))
		_shake(8.0, 0.3)
		_spawn_float_text("-$500", Color("ef4444"), _event_panel)
	await get_tree().create_timer(1.2).timeout
	if gm.trader.get("balance", 0) <= 0:
		_show_liquidated()
		return
	_close_event_and_advance()

func _event_walk_away() -> void:
	SFX.play_swipe(self)
	_close_event_and_advance()

func _close_event_and_advance() -> void:
	_event_panel.visible = false
	_round_card_index += 1
	_queue_index += 1
	if _round_card_index >= ROUND_SIZE or _queue_index >= _market_queue.size():
		_show_round_summary()
		return
	card_container.visible = true
	wager_bar.visible = true
	if _relic_bar:
		_relic_bar.visible = true
	_populate_card()

# === BOSS DEFEATED ===

func _show_boss_defeated() -> void:
	var popup = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.02, 0.04, 0.92)
	s.border_color = Color("f59e0b")
	s.set_border_width_all(3)
	s.set_corner_radius_all(16)
	s.set_content_margin_all(32)
	popup.add_theme_stylebox_override("panel", s)
	popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	popup.z_index = 200

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	popup.add_child(vbox)

	var title = Label.new()
	title.text = "BOSS DEFEATED"
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("f59e0b"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = "You conquered the market boss!"
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color("e0e0f0"))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(desc)

	add_child(popup)

	popup.pivot_offset = popup.size / 2.0
	popup.scale = Vector2(0.3, 0.3)
	popup.modulate.a = 0.0
	var tw = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_property(popup, "scale", Vector2(1.1, 1.1), 0.4)
	tw.parallel().tween_property(popup, "modulate:a", 1.0, 0.2)
	tw.tween_property(popup, "scale", Vector2.ONE, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(popup, "modulate:a", 0.0, 0.3)
	tw.tween_callback(popup.queue_free)

	_shake(10.0, 0.4)
	_camera_kick(0.06)
	SFX.play_streak(self)
	_flash(Color(0.96, 0.62, 0.04, 0.25))

func _drop_relic_reward() -> void:
	# Give a random relic on elite card win
	var relic_keys = ["leverage_tokens", "stop_loss", "insider_info"]
	var chosen = relic_keys[randi() % relic_keys.size()]
	gm.relics[chosen] = gm.relics.get(chosen, 0) + 1
	_update_relic_bar()
	var name_map = {"leverage_tokens": "3x LEVERAGE", "stop_loss": "STOP LOSS", "insider_info": "INSIDER INFO"}
	_spawn_float_text("RELIC: %s" % name_map[chosen], Color("f59e0b"), swipe_balance)

# === CINEMATIC TERMINAL INTRO ===

func _build_intro_panel() -> void:
	_intro_panel = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	s.set_border_width_all(0)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(32)
	_intro_panel.add_theme_stylebox_override("panel", s)
	_intro_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_intro_panel.z_index = 300
	_intro_panel.visible = false

	_intro_terminal = RichTextLabel.new()
	_intro_terminal.bbcode_enabled = true
	_intro_terminal.scroll_following = true
	_intro_terminal.add_theme_font_size_override("normal_font_size", 14)
	_intro_terminal.add_theme_color_override("default_color", Color("10b981"))
	_intro_terminal.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_intro_terminal.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_intro_panel.add_child(_intro_terminal)

	add_child(_intro_panel)

func _play_intro_sequence() -> void:
	_intro_active = true
	_hide_all()
	_intro_panel.visible = true
	_intro_terminal.text = ""

	# Start ambient drone immediately
	SFX.start_drone(self)

	var lines = [
		{"text": "> INITIALIZING DOJO WORLD ENGINE...", "color": "10b981", "delay": 0.4},
		{"text": "> SYNCING KATANA SEQUENCER: BLOCK #%d" % (randi() % 90000 + 10000), "color": "10b981", "delay": 0.3},
		{"text": "> ESTABLISHING CARTRIDGE SECURE SESSION...", "color": "38bdf8", "delay": 0.5},
		{"text": "> TORII INDEXER: CONNECTED", "color": "38bdf8", "delay": 0.25},
		{"text": "> LOADING 75 PREDICTION MARKETS...", "color": "a855f7", "delay": 0.4},
		{"text": "> VERIFYING ONCHAIN STATE: OK", "color": "10b981", "delay": 0.2},
		{"text": "> SESSION KEY: ACTIVE", "color": "38bdf8", "delay": 0.3},
		{"text": "> WORLD BOSS STATUS: AWAITING CHALLENGERS", "color": "ef4444", "delay": 0.35},
		{"text": "", "color": "10b981", "delay": 0.3},
		{"text": "> WELCOME TO", "color": "e0e0f0", "delay": 0.5},
	]

	for line_data in lines:
		if not is_inside_tree() or not _intro_active:
			return
		await _type_line(line_data["text"], Color(line_data["color"]), 0.015)
		await get_tree().create_timer(line_data["delay"]).timeout

	# The big title — typed slower with purple
	if not is_inside_tree() or not _intro_active:
		return
	await _type_line("> P R O P H E C Y", Color("a855f7"), 0.06)
	await get_tree().create_timer(0.8).timeout

	if not is_inside_tree() or not _intro_active:
		return

	# WHITE FLASH + BASS DROP → fade to start screen
	SFX.play_bass_drop(self)
	flash_rect.color = Color(1.0, 1.0, 1.0, 1.0)
	flash_rect.visible = true
	flash_rect.z_index = 400

	await get_tree().create_timer(0.1).timeout
	if not is_inside_tree():
		return

	_intro_active = false
	_intro_panel.visible = false
	flash_rect.z_index = 0
	# Fade white flash out
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.5)
	tw.tween_callback(func(): flash_rect.visible = false)

	_show_start()
	_shake(6.0, 0.3)
	_camera_kick(0.04)

func _type_line(text: String, color: Color, char_delay: float) -> void:
	if text.is_empty():
		_intro_terminal.append_text("\n")
		return
	var hex = color.to_html(false)
	_intro_terminal.append_text("[color=#%s]" % hex)
	for ch in text:
		if not is_inside_tree() or not _intro_active:
			return
		_intro_terminal.append_text(ch)
		SFX.play_type_tick(self)
		await get_tree().create_timer(char_delay).timeout
	_intro_terminal.append_text("[/color]\n")

# === DIEGETIC UI: CARD SLOT BRACKETS ===

func _build_card_slot_brackets() -> void:
	# Glowing bracket guides on left/right edges of card area
	_bracket_left = Label.new()
	_bracket_left.text = "["
	_bracket_left.add_theme_font_size_override("font_size", 64)
	_bracket_left.add_theme_color_override("font_color", Color(0.55, 0.35, 1.0, 0.3))
	_bracket_left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_bracket_left.position.x = 8
	_bracket_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_area.add_child(_bracket_left)

	_bracket_right = Label.new()
	_bracket_right.text = "]"
	_bracket_right.add_theme_font_size_override("font_size", 64)
	_bracket_right.add_theme_color_override("font_color", Color(0.55, 0.35, 1.0, 0.3))
	_bracket_right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_bracket_right.position.x = -24
	_bracket_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_area.add_child(_bracket_right)

func _apply_letter_spacing() -> void:
	# Add letter spacing to key labels for premium "hacker terminal" feel
	# Godot 4: use theme variation with custom spacing via LabelSettings
	var ls = LabelSettings.new()
	ls.font_size = 14
	ls.font_color = Color("e0e0f0")
	ls.line_spacing = 2.0

	# Apply tracking to leaderboard title and chain status for premium look
	chain_status.uppercase = true
	tx_label.uppercase = true

	# Wider letter spacing on key header labels
	for lbl in [swipe_progress, timer_label]:
		lbl.add_theme_constant_override("outline_size", 0)

# === ORACLE ADMIN PANEL (Ctrl+Shift+O) ===

func _toggle_oracle_panel() -> void:
	if not _oracle_panel:
		_build_oracle_panel()
	if _oracle_panel.visible:
		_oracle_panel.visible = false
	else:
		_populate_oracle_panel()
		_oracle_panel.visible = true

func _build_oracle_panel() -> void:
	_oracle_panel = PanelContainer.new()
	var s = StyleBoxFlat.new()
	s.bg_color = Color(0.08, 0.02, 0.02, 0.97)
	s.border_color = Color(0.8, 0.1, 0.1, 0.6)
	s.set_border_width_all(2)
	s.set_corner_radius_all(0)
	s.set_content_margin_all(20)
	_oracle_panel.add_theme_stylebox_override("panel", s)
	_oracle_panel.anchors_preset = Control.PRESET_FULL_RECT
	_oracle_panel.visible = false
	add_child(_oracle_panel)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_oracle_panel.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# Header
	var title = Label.new()
	title.text = "JUDGMENT DAY"
	title.add_theme_color_override("font_color", Color(0.9, 0.15, 0.15))
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.uppercase = true
	vbox.add_child(title)

	var sub = Label.new()
	sub.text = "Oracle Admin  //  Ctrl+Shift+O to close"
	sub.add_theme_color_override("font_color", Color(0.5, 0.2, 0.2))
	sub.add_theme_font_size_override("font_size", 12)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub)

	var sep = HSeparator.new()
	sep.add_theme_color_override("separator", Color(0.4, 0.1, 0.1))
	vbox.add_child(sep)

	_oracle_list = VBoxContainer.new()
	_oracle_list.add_theme_constant_override("separation", 6)
	vbox.add_child(_oracle_list)

func _populate_oracle_panel() -> void:
	for child in _oracle_list.get_children():
		child.queue_free()
	# List all unresolved markets
	var unresolved: Array[int] = []
	for mid in GameManager.MARKET_DATA:
		var market = gm.markets.get(mid, {})
		if not market.get("is_resolved", false):
			unresolved.append(mid)
	unresolved.sort()
	if unresolved.size() == 0:
		var lbl = Label.new()
		lbl.text = "All markets resolved."
		lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
		lbl.add_theme_font_size_override("font_size", 14)
		_oracle_list.add_child(lbl)
		return
	for mid in unresolved:
		_add_oracle_row(mid)

func _add_oracle_row(mid: int) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var id_lbl = Label.new()
	id_lbl.text = "#%d" % mid
	id_lbl.add_theme_color_override("font_color", Color(0.6, 0.2, 0.2))
	id_lbl.add_theme_font_size_override("font_size", 12)
	id_lbl.custom_minimum_size.x = 35
	row.add_child(id_lbl)

	var title = Label.new()
	title.text = gm.get_market_title(mid)
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	title.add_theme_font_size_override("font_size", 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(title)

	var btn_yes = Button.new()
	btn_yes.text = "FORCE YES"
	btn_yes.add_theme_font_size_override("font_size", 11)
	_apply_button_style(btn_yes, Color("10b981"))
	btn_yes.custom_minimum_size = Vector2(85, 26)
	var cap_mid = mid
	btn_yes.pressed.connect(func():
		gm.resolve_market_on_chain(cap_mid, true)
		btn_yes.disabled = true
		btn_yes.text = "SENT"
	)
	row.add_child(btn_yes)

	var btn_no = Button.new()
	btn_no.text = "FORCE NO"
	btn_no.add_theme_font_size_override("font_size", 11)
	_apply_button_style(btn_no, Color("ef4444"))
	btn_no.custom_minimum_size = Vector2(85, 26)
	btn_no.pressed.connect(func():
		gm.resolve_market_on_chain(cap_mid, false)
		btn_no.disabled = true
		btn_no.text = "SENT"
	)
	row.add_child(btn_no)

	_oracle_list.add_child(row)

# === BUTTON PULSE ===

func _pulse_button(btn: Button) -> void:
	btn.pivot_offset = btn.size / 2.0
	var tw = create_tween().set_loops()
	tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_property(btn, "scale", Vector2.ONE, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Also pulse modulate for glow effect
	var tw2 = create_tween().set_loops()
	tw2.tween_property(btn, "modulate", Color(1.2, 1.1, 1.3, 1.0), 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw2.tween_property(btn, "modulate", Color.WHITE, 0.8).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
