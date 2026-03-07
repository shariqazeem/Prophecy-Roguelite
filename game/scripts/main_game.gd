extends Control

@onready var gm: GameManager = %GameManager

# Panels
@onready var start_panel: PanelContainer = %StartPanel
@onready var game_panel: VBoxContainer = %GamePanel
@onready var gameover_panel: PanelContainer = %GameOverPanel

# Start
@onready var btn_start: Button = %BtnStart
@onready var start_status: Label = %StartStatus

# HUD
@onready var hp_bar: ProgressBar = %HPBar
@onready var hp_label: Label = %HPLabel
@onready var floor_label: Label = %FloorLabel
@onready var gold_label: Label = %GoldLabel
@onready var streak_label: Label = %StreakLabel
@onready var acc_label: Label = %AccLabel
@onready var tier_label: Label = %TierLabel

# Center area
@onready var center_card: PanelContainer = %CenterCard
@onready var center_title: Label = %CenterTitle
@onready var center_icon: Label = %CenterIcon
@onready var clue_label: Label = %ClueLabel
@onready var clue_detail: Label = %ClueDetail
@onready var center_result: Label = %CenterResult
@onready var center_detail: Label = %CenterDetail

# Wager
@onready var wager_row: HBoxContainer = %WagerRow
@onready var btn_safe: Button = %BtnSafe
@onready var btn_risky: Button = %BtnRisky
@onready var btn_all_in: Button = %BtnAllIn
@onready var wager_label: Label = %WagerLabel

# Prediction buttons
@onready var pred_grid: GridContainer = %PredGrid
@onready var btn_monster: Button = %BtnMonster
@onready var btn_trap: Button = %BtnTrap
@onready var btn_treasure: Button = %BtnTreasure
@onready var btn_heal: Button = %BtnHeal

# Status bar
@onready var chain_status: Label = %ChainStatus
@onready var tx_label: Label = %TxLabel

# History
@onready var history_label: RichTextLabel = %HistoryLabel

# Game over
@onready var go_score: Label = %GOScore
@onready var go_stats: Label = %GOStats
@onready var go_new_record: Label = %GONewRecord
@onready var go_high_score: Label = %GOHighScore
@onready var btn_retry: Button = %BtnRetry

# Screen flash
@onready var flash_rect: ColorRect = %FlashRect

# Background
@onready var background: ColorRect = $Background

var is_revealing: bool = false
var history: Array = []
var current_wager: int = 0

func _ready() -> void:
	gm.state_updated.connect(_on_state)
	gm.round_resolved.connect(_on_round)
	gm.player_died.connect(_on_died)
	gm.player_spawned.connect(_on_spawned)
	gm.tx_status.connect(_on_tx)
	gm.connection.tx_started.connect(_on_tx_started)

	btn_start.pressed.connect(_start)
	btn_retry.pressed.connect(_retry)
	btn_monster.pressed.connect(func(): _predict(0))
	btn_trap.pressed.connect(func(): _predict(1))
	btn_treasure.pressed.connect(func(): _predict(2))
	btn_heal.pressed.connect(func(): _predict(3))

	btn_safe.pressed.connect(func(): _set_wager(0))
	btn_risky.pressed.connect(func(): _set_wager(gm.player.get("gold", 0) / 4))
	btn_all_in.pressed.connect(func(): _set_wager(gm.player.get("gold", 0)))

	_apply_button_style(btn_monster, Color("ef4444"))  # CRASH — red
	_apply_button_style(btn_trap, Color("f59e0b"))     # RUG — orange
	_apply_button_style(btn_treasure, Color("10b981")) # MOON — green
	_apply_button_style(btn_heal, Color("6366f1"))     # RALLY — indigo
	_apply_button_style(btn_start, Color("6366f1"))
	_apply_button_style(btn_retry, Color("6366f1"))
	_apply_button_style(btn_safe, Color("9ca3af"))
	_apply_button_style(btn_risky, Color("f59e0b"))
	_apply_button_style(btn_all_in, Color("ef4444"))

	_show_start()

# === SCREENS ===

func _show_start() -> void:
	start_panel.visible = true
	game_panel.visible = false
	gameover_panel.visible = false
	start_status.text = ""
	btn_start.disabled = false

func _show_game() -> void:
	start_panel.visible = false
	gameover_panel.visible = false
	game_panel.visible = true
	game_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(game_panel, "modulate:a", 1.0, 0.4)
	_show_waiting()

func _show_waiting() -> void:
	var next_floor = gm.player.get("floor", 0) + 1
	var is_boss = next_floor % 5 == 0 and next_floor > 0

	# Round title
	if is_boss:
		center_title.text = "BLACK SWAN — ROUND %d" % next_floor
		center_title.add_theme_color_override("font_color", Color("ef4444"))
	else:
		center_title.text = "ROUND %d" % next_floor
		center_title.add_theme_color_override("font_color", Color("8b8da0"))

	center_icon.text = "$" if not is_boss else "⚡"
	center_icon.add_theme_color_override("font_color", Color("ef4444") if is_boss else Color("6b7280"))
	center_result.text = "What's the next move?"
	center_result.add_theme_color_override("font_color", Color("8b8da0"))

	# Clues
	var ct = gm.player.get("clue_type", 0)
	var cd = gm.player.get("clue_detail", 0)
	if ct == 0:
		clue_label.text = "Bearish signals detected..."
		clue_label.add_theme_color_override("font_color", Color("ef4444"))
	else:
		clue_label.text = "Bullish indicators rising..."
		clue_label.add_theme_color_override("font_color", Color("10b981"))

	match cd:
		1: clue_detail.text = "...not a Crash"
		2: clue_detail.text = "...not a Rug"
		3: clue_detail.text = "...not a Moon"
		4: clue_detail.text = "...not a Rally"
		_: clue_detail.text = ""
	clue_detail.add_theme_color_override("font_color", Color("8b8da0"))

	# Stakes
	var base_dmg = 10 + next_floor * 2
	var boss_mult = " (2x BLACK SWAN)" if is_boss else ""
	center_detail.text = "Correct = profit | Wrong = -$%d capital risk%s" % [base_dmg, boss_mult]
	center_detail.add_theme_color_override("font_color", Color("8b8da0"))

	# Wager row
	current_wager = 0
	var gold = gm.player.get("gold", 0)
	if gold > 0:
		wager_row.visible = true
		_update_wager_label()
	else:
		wager_row.visible = false

	# Market phase shader
	var biome = clampi(next_floor / 5, 0, 3)
	if background and background.material:
		background.material.set_shader_parameter("biome", float(biome))

	_set_predictions_enabled(true)

func _set_wager(amount: int) -> void:
	current_wager = clampi(amount, 0, gm.player.get("gold", 0))
	_update_wager_label()

func _update_wager_label() -> void:
	if current_wager == 0:
		wager_label.text = "Position: $0"
		wager_label.add_theme_color_override("font_color", Color("8b8da0"))
	else:
		wager_label.text = "Position: $%d" % current_wager
		wager_label.add_theme_color_override("font_color", Color("f59e0b"))

# === ACTIONS ===

func _start() -> void:
	btn_start.disabled = true
	start_status.text = "Connecting to Starknet..."
	gm.connection.setup()
	# Wait for connection (Controller may take time for browser auth)
	while not gm.connection._is_connected:
		await get_tree().create_timer(0.3).timeout
	if gm.connection.use_controller and gm.connection.use_slot:
		start_status.text = "Authenticating via Cartridge..."
		while not gm.connection._controller_ready and gm.connection._session_account != null:
			await get_tree().create_timer(0.5).timeout
	start_status.text = "Spawning on-chain..."
	chain_status.text = "Cartridge Slot" if gm.connection.use_slot else "Katana"
	gm.spawn()

func _predict(choice: int) -> void:
	if is_revealing or gm.is_busy:
		return
	_set_predictions_enabled(false)
	wager_row.visible = false
	var names = ["Crash", "Rug", "Moon", "Rally"]
	var next_floor = gm.player.get("floor", 0) + 1
	center_title.text = "ROUND %d" % next_floor
	center_title.add_theme_color_override("font_color", Color("8b8da0"))
	center_icon.text = "..."
	center_icon.add_theme_color_override("font_color", Color("6366f1"))
	center_result.text = "Predicted: %s" % names[choice]
	center_result.add_theme_color_override("font_color", Color("6366f1"))
	clue_label.text = ""
	clue_detail.text = ""
	var wager_text = " (position: $%d)" % current_wager if current_wager > 0 else ""
	center_detail.text = "Submitting to chain...%s" % wager_text
	center_detail.add_theme_color_override("font_color", Color("8b8da0"))
	gm.predict(choice, current_wager)
	current_wager = 0

func _retry() -> void:
	btn_retry.disabled = true
	gm.spawn()

# === CALLBACKS ===

func _on_state(data: Dictionary) -> void:
	var hp = data.get("hp", 100)
	var max_hp = data.get("max_hp", 100)
	hp_bar.max_value = max_hp
	# Animate HP
	var tw = create_tween()
	tw.tween_property(hp_bar, "value", float(hp), 0.3)
	hp_label.text = "%d/%d" % [hp, max_hp]

	var floor_num = data.get("floor", 0)
	floor_label.text = "Round %d" % floor_num if floor_num > 0 else "Pre-Market"

	gold_label.text = "$%d" % data.get("gold", 0)

	var streak = data.get("streak", 0)
	if streak > 2:
		streak_label.text = "%dx streak!" % streak
		streak_label.add_theme_color_override("font_color", Color("f59e0b"))
	else:
		streak_label.text = "%dx" % streak
		streak_label.add_theme_color_override("font_color", Color("8b8da0"))

	var total = data.get("total", 0)
	var correct = data.get("correct", 0)
	if total > 0:
		acc_label.text = "%d%%" % ((correct * 100) / total)
	else:
		acc_label.text = "-"

	# Streak tier badge
	var st = data.get("streak_tier", 0)
	match st:
		1:
			tier_label.visible = true
			tier_label.text = "HOT HAND"
			tier_label.add_theme_color_override("font_color", Color("f59e0b"))
		2:
			tier_label.visible = true
			tier_label.text = "ON FIRE"
			tier_label.add_theme_color_override("font_color", Color("f97316"))
		3:
			tier_label.visible = true
			tier_label.text = "ORACLE"
			tier_label.add_theme_color_override("font_color", Color("a855f7"))
		_:
			tier_label.visible = false

	# HP bar color
	var ratio = float(hp) / float(max_hp) if max_hp > 0 else 1.0
	if ratio <= 0.25:
		hp_bar.modulate = Color("ef4444")
	elif ratio <= 0.5:
		hp_bar.modulate = Color("f59e0b")
	else:
		hp_bar.modulate = Color("10b981")

func _on_round(rd: Dictionary) -> void:
	is_revealing = true
	var ev = rd.get("event", 0)
	var correct = rd.get("correct", false)
	var floor_num = rd.get("floor", 0)
	var is_boss = rd.get("is_boss", false)
	var wager = rd.get("wager", 0)
	var names = ["Crash", "Rug", "Moon", "Rally"]
	var icons = ["↓", "⚠", "↑", "♻"]
	var color = GameManager.event_color(ev)

	# Track history
	history.append({"event": ev, "correct": correct})
	_update_history()

	if is_boss:
		center_title.text = "BLACK SWAN — ROUND %d" % floor_num
		center_title.add_theme_color_override("font_color", Color("ef4444"))
	else:
		center_title.text = "ROUND %d" % floor_num
		center_title.add_theme_color_override("font_color", Color("8b8da0"))

	center_icon.text = icons[ev]
	center_icon.add_theme_color_override("font_color", color)

	# Bounce animation (enhanced for boss)
	center_icon.pivot_offset = center_icon.size / 2.0
	var bounce_scale = 1.3 if is_boss else 1.15
	center_icon.scale = Vector2(0.3, 0.3)
	var tw = create_tween()
	tw.tween_property(center_icon, "scale", Vector2(bounce_scale, bounce_scale), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(center_icon, "scale", Vector2.ONE, 0.1)

	if correct:
		center_result.text = "PROFIT!"
		center_result.add_theme_color_override("font_color", Color("10b981"))
		_flash(Color(0.06, 0.78, 0.45, 0.15 if is_boss else 0.12))
	else:
		center_result.text = "LOSS"
		center_result.add_theme_color_override("font_color", Color("ef4444"))
		_flash(Color(0.94, 0.27, 0.27, 0.15 if is_boss else 0.12))
		_shake()

	# Build outcome detail
	var parts: PackedStringArray = []
	parts.append(names[ev])
	if is_boss:
		parts.append("BLACK SWAN")
	if rd.get("damage", 0) > 0:
		parts.append("-$%d" % rd["damage"])
	if rd.get("gold", 0) > 0:
		parts.append("+$%d" % rd["gold"])
	if rd.get("heal", 0) > 0:
		parts.append("+$%d capital" % rd["heal"])

	# Wager result
	if wager > 0:
		if correct:
			parts.append("+$%d position!" % wager)
		else:
			parts.append("-$%d position" % wager)

	# Show streak on correct
	if correct:
		var streak = gm.player.get("streak", 0)
		if streak > 1:
			parts.append("%dx streak!" % streak)
	else:
		var alt = _correct_outcome_hint(ev, floor_num)
		if alt != "":
			parts.append("(if correct: %s)" % alt)

	center_detail.text = " · ".join(parts)
	center_detail.add_theme_color_override("font_color", color.lerp(Color("8b8da0"), 0.3))
	clue_label.text = ""
	clue_detail.text = ""

	await get_tree().create_timer(1.2).timeout
	is_revealing = false
	if gm.player.get("is_alive", true):
		_show_waiting()

func _on_died(score: int) -> void:
	_set_predictions_enabled(false)
	wager_row.visible = false
	await get_tree().create_timer(1.2).timeout
	game_panel.visible = false
	gameover_panel.visible = true
	gameover_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(gameover_panel, "modulate:a", 1.0, 0.5)

	go_score.text = str(score)
	var p = gm.player
	var acc = 0
	if p.get("total", 0) > 0:
		acc = (p["correct"] * 100) / p["total"]
	go_stats.text = "Round %d · $%d profit · %d%% accuracy · %dx best streak" % [
		p.get("floor", 0), p.get("gold", 0), acc, p.get("best_streak", 0)
	]

	# Leaderboard comparison
	var lb = gm.leaderboard
	var prev_high = lb.get("high_score", 0)
	var total_runs = lb.get("total_runs", 0)
	if prev_high > 0 and score >= prev_high:
		go_new_record.visible = true
		go_new_record.text = "NEW HIGH SCORE!"
		# Pulse animation
		var tw2 = create_tween().set_loops()
		tw2.tween_property(go_new_record, "modulate:a", 0.5, 0.5)
		tw2.tween_property(go_new_record, "modulate:a", 1.0, 0.5)
	else:
		go_new_record.visible = false

	if prev_high > 0 or total_runs > 0:
		var parts: PackedStringArray = []
		if prev_high > 0 and score < prev_high:
			parts.append("Best: %d" % prev_high)
		if lb.get("highest_floor", 0) > 0:
			parts.append("Best: Round %d" % lb["highest_floor"])
		if total_runs > 0:
			parts.append("Session #%d" % (total_runs + 1))
		go_high_score.text = " · ".join(parts)
	else:
		go_high_score.text = "First session!"

func _on_spawned() -> void:
	gameover_panel.visible = false
	go_new_record.visible = false
	btn_retry.disabled = false
	history.clear()
	_update_history()
	current_wager = 0
	# Reset market phase
	if background and background.material:
		background.material.set_shader_parameter("biome", 0.0)
	_show_game()

func _on_tx_started(entrypoint: String) -> void:
	tx_label.text = entrypoint + "..."

func _on_tx(entrypoint: String, success: bool, tx_hash: String) -> void:
	# Handle spawn failure
	if not success:
		if entrypoint == "spawn":
			btn_start.disabled = false
			btn_retry.disabled = false
			start_status.text = "Failed. Try again."
		tx_label.text = "tx failed"
		return

	if tx_hash.length() > 10:
		tx_label.text = "tx: " + tx_hash.left(10) + "..."
	else:
		tx_label.text = "confirmed"

# === HISTORY ===

func _update_history() -> void:
	var icons = ["↓", "⚠", "↑", "♻"]
	var colors = ["#ef4444", "#f59e0b", "#10b981", "#6366f1"]
	var bbcode = ""
	var recent = history.slice(-10) if history.size() > 10 else history
	for h in recent:
		if bbcode != "":
			bbcode += "  "
		var ev: int = h["event"]
		var c: bool = h["correct"]
		var icon = icons[ev]
		if c:
			bbcode += "[color=%s][b]%s[/b][/color]" % [colors[ev], icon]
		else:
			bbcode += "[color=#6b7280]%s[/color]" % icon
	if bbcode == "":
		history_label.text = "[center][color=#8b8da0]Trade history will appear here[/color][/center]"
	else:
		history_label.text = "[center]" + bbcode + "[/center]"

# Show what the correct outcome would have been
func _correct_outcome_hint(ev: int, floor_num: int) -> String:
	var base_dmg = 10 + floor_num * 2
	var base_gold = 5 + floor_num
	match ev:
		0: return "-$%d, +$%d" % [base_dmg / 2, base_gold]
		1: return "+$%d" % [base_gold / 2]
		2: return "+$%d" % [base_gold * 3]
		3: return "+$%d capital" % [15 + 5]
	return ""

# === EFFECTS ===

func _flash(color: Color) -> void:
	flash_rect.color = color
	flash_rect.visible = true
	var tw = create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, 0.35)
	tw.tween_callback(func(): flash_rect.visible = false)

func _shake() -> void:
	var orig = position
	var tw = create_tween()
	for i in range(5):
		tw.tween_property(self, "position", orig + Vector2(randf_range(-6, 6), randf_range(-4, 4)), 0.04)
	tw.tween_property(self, "position", orig, 0.04)

func _set_predictions_enabled(on: bool) -> void:
	btn_monster.disabled = not on
	btn_trap.disabled = not on
	btn_treasure.disabled = not on
	btn_heal.disabled = not on

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
