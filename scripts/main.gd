extends Node2D

const TutorialOverlay    = preload("res://scenes/tutorial_overlay.tscn")
const LevelCompleteScreen = preload("res://scenes/level_complete.tscn")

# ── Scene references ───────────────────────────────────────────────────────────
@onready var robot         : Robot         = $GameWorld/Robot
@onready var block_manager : BlockManager  = $GameWorld/BlockManager
@onready var workspace     : HBoxContainer = $UI/WorkspacePanel/Workspace
@onready var run_button    : Button        = $UI/RunButton
@onready var count_label   : Label         = $UI/ActionCounterPanel/VBoxContainer/CountLabel
@onready var title_label   : Label         = $UI/ActionCounterPanel/VBoxContainer/TitleLabel
@onready var btn_backspace : Button        = $UI/BackspaceButton

@onready var btn_up     : Button = $UI/CommandPalette/UpButton
@onready var btn_down   : Button = $UI/CommandPalette/DownButton
@onready var btn_left   : Button = $UI/CommandPalette/LeftButton
@onready var btn_right  : Button = $UI/CommandPalette/RightButton
@onready var btn_attack : Button = $UI/CommandPalette/AttackButton
@onready var btn_loop   : Button = $UI/CommandPalette/LoopButton
@onready var btn_append : Button = $UI/CommandPalette/AppendButton

# ── Level list ─────────────────────────────────────────────────────────────────
@export var levels : Array[String] = [
	#"res://levels/level_1.tres",
	#"res://levels/level_2.tres",
	#"res://levels/level_3.tres",
	#"res://levels/level_4.tres",
	#"res://levels/level_5.tres",
	#"res://levels/level_6.tres",
	"res://levels/level_7.tres",
	"res://levels/level_8.tres",
]

# ── IF-ELSE unlock threshold ───────────────────────────────────────────────────
# Levels AT OR ABOVE this index can use IF-ELSE mode (if their .tres opts in).
# SET TO 0  → IF-ELSE works immediately for testing (skips no levels).
# SET TO 6  → normal game: levels 1-6 standard, level 7+ can be IF-ELSE.
const IF_ELSE_UNLOCK_FROM_LEVEL : int = 0

# ── Blueprint definitions ─────────────────────────────────────────────────────
# Blueprints live here in code, NOT in .tres files, because Godot's resource
# format cannot reliably serialize nested Dictionaries with null values.
# Key = level_name string (must match the level_name field in the .tres).
# Each entry is an Array of block definitions. Use "?" for blank dropdown slots.
const BLUEPRINTS : Dictionary = {
	"Level 7 - The Algorithm": [
		{
			"repeat_count":    7,
			"check_direction": "?",
			"check_condition": "?",
			"then_action":     "?",
			"else_action":     "?"
		},
		{
			"repeat_count":    13,
			"check_direction": "?",
			"check_condition": "?",
			"then_action":     "?",
			"else_action":     "?"
		}
	],
	# Add more IF-ELSE level blueprints here as you create them:
	# "Level 8 - Another IF Level": [
	#     { "repeat_count": 8, "check_direction": "RIGHT", "check_condition": "?", "then_action": "?", "else_action": "?" }
	# ],
}

# ── State ──────────────────────────────────────────────────────────────────────
var current_level_index   : int  = 0
var command_blocks        : Array[CommandBlock] = []
var is_executing          : bool = false
var current_command_index : int  = 0
var total_actions_taken   : int  = 0
var max_actions           : int  = 8
var _level_complete       : bool = false
var _is_if_else_mode      : bool = false
var _tutorial_seen        : Array[bool] = []

# ── IF-ELSE blueprint widgets ──────────────────────────────────────────────────
var _if_else_blocks    : Array           = []   # Array[RepeatIfElseBlock]
var _if_else_workspace : VBoxContainer  = null
var _if_else_scroll    : ScrollContainer = null

# ── Pending modifier state ─────────────────────────────────────────────────────
enum PendingMode { NONE, LOOP, APPEND_FIRST, APPEND_SECOND }
var _pending_mode         : PendingMode = PendingMode.NONE
var _pending_first_action : CommandBlock.CommandType = CommandBlock.CommandType.MOVE_UP

# ── Help panel ─────────────────────────────────────────────────────────────────
var _help_panel  : PanelContainer = null
var _help_button : Button         = null

# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	var spr = robot.get_node_or_null("Sprite2D")
	if spr: spr.queue_free()

	btn_up.pressed.connect(func():     _on_basic_pressed(CommandBlock.CommandType.MOVE_UP))
	btn_down.pressed.connect(func():   _on_basic_pressed(CommandBlock.CommandType.MOVE_DOWN))
	btn_left.pressed.connect(func():   _on_basic_pressed(CommandBlock.CommandType.MOVE_LEFT))
	btn_right.pressed.connect(func():  _on_basic_pressed(CommandBlock.CommandType.MOVE_RIGHT))
	btn_attack.pressed.connect(func(): _on_basic_pressed(CommandBlock.CommandType.ATTACK))
	btn_loop.pressed.connect(_on_loop_pressed)
	btn_append.pressed.connect(_on_append_pressed)
	run_button.pressed.connect(_on_run_pressed)
	btn_backspace.pressed.connect(_remove_last_cmd)
	robot.action_completed.connect(_on_action_completed)
	block_manager.level_complete.connect(_on_level_complete)
	robot.block_manager = block_manager

	_tutorial_seen.resize(levels.size())
	_tutorial_seen.fill(false)

	_build_help_ui()
	_build_if_else_workspace()
	_load_level(current_level_index)

# ── IF-ELSE scrollable workspace (built once, toggled per level) ───────────────
func _build_if_else_workspace() -> void:
	var workspace_panel = $UI/WorkspacePanel

	_if_else_scroll = ScrollContainer.new()
	_if_else_scroll.name = "IfElseScroll"
	_if_else_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_if_else_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_if_else_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_if_else_scroll.visible = false

	_if_else_workspace = VBoxContainer.new()
	_if_else_workspace.add_theme_constant_override("separation", 10)
	_if_else_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_if_else_scroll.add_child(_if_else_workspace)

	workspace_panel.add_child(_if_else_scroll)

# ── Help UI ────────────────────────────────────────────────────────────────────
func _build_help_ui() -> void:
	var ui_layer = $UI
	_help_button = Button.new()
	_help_button.text = "?"
	_help_button.custom_minimum_size = Vector2(36, 36)
	_help_button.anchor_left = 1.0; _help_button.anchor_right  = 1.0
	_help_button.anchor_top  = 0.5; _help_button.anchor_bottom = 0.5
	_help_button.offset_left = -50.0; _help_button.offset_right  = -14.0
	_help_button.offset_top  = -18.0; _help_button.offset_bottom =  18.0
	_help_button.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(_help_button)
	_help_button.pressed.connect(_on_help_pressed)

	_help_panel = PanelContainer.new()
	_help_panel.anchor_left = 1.0; _help_panel.anchor_right  = 1.0
	_help_panel.anchor_top  = 0.5; _help_panel.anchor_bottom = 0.5
	_help_panel.offset_left = -310.0; _help_panel.offset_right  = -52.0
	_help_panel.offset_top  = -200.0; _help_panel.offset_bottom =  200.0
	var style := StyleBoxFlat.new()
	style.bg_color      = Color(0.10, 0.10, 0.16, 0.97)
	style.border_color  = Color(0.40, 0.40, 0.70, 1.0)
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 2)
		style.set("corner_radius_top_" + ("left" if side == "left" else "right"), 6)
	style.corner_radius_top_left     = 6; style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6; style.corner_radius_bottom_right = 6
	_help_panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",  12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top",   10)
	margin.add_theme_constant_override("margin_bottom",10)
	_help_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var title := Label.new()
	title.text = "Commands"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())
	for entry in [
		["↑  ↓  ←  →", "Move (slide until wall)."],
		["⚔  ATTACK",   "Break block ahead (−1 HP)."],
		["↺  LOOP ×3",  "Repeat action 3×, 1 slot."],
		["&&  APPEND",  "Chain 2 actions, 1 slot."],
		["↺ REPEAT-IF", "Repeat N× with if/else."],
	]:
		var row := VBoxContainer.new(); row.add_theme_constant_override("separation", 2)
		vbox.add_child(row)
		var cl := Label.new(); cl.text = entry[0]
		cl.add_theme_font_size_override("font_size", 14)
		cl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row.add_child(cl)
		var dl := Label.new(); dl.text = entry[1]
		dl.add_theme_font_size_override("font_size", 12)
		dl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(dl)
		var sp := Control.new(); sp.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(sp)
	var close_btn := Button.new(); close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(func(): _help_panel.visible = false)
	vbox.add_child(close_btn)
	_help_panel.visible = false
	ui_layer.add_child(_help_panel)

func _on_help_pressed() -> void:
	_help_panel.visible = not _help_panel.visible

# ── Level loading ──────────────────────────────────────────────────────────────
func _load_level(index: int) -> void:
	if index >= levels.size():
		_show_win_screen(); return

	var data : LevelData = load(levels[index]) as LevelData
	if data == null:
		push_error("Could not load: " + levels[index]); return

	max_actions     = data.action_limit
	_level_complete = false
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	_clear_commands()
	_pending_mode         = PendingMode.NONE
	total_actions_taken   = 0
	current_command_index = 0
	is_executing          = false
	run_button.disabled   = false
	if title_label: title_label.text = data.level_name
	_clear_palette_hint()

	# Decide mode
	var unlock_ok : bool = (index >= IF_ELSE_UNLOCK_FROM_LEVEL)
	_is_if_else_mode = data.use_if_else_mode and unlock_ok

	if _is_if_else_mode:
		_enter_if_else_mode(data)
	else:
		_enter_standard_mode(data)

	_update_counter()

	if index < _tutorial_seen.size() and not _tutorial_seen[index]:
		_tutorial_seen[index] = true
		_show_tutorial(index)

func _reload_current_level() -> void:
	_load_level(current_level_index)

# ── Standard mode ──────────────────────────────────────────────────────────────
func _enter_standard_mode(data: LevelData) -> void:
	$UI/CommandPalette.visible     = true
	$UI/BackspaceButton.visible    = true
	$UI/ActionCounterPanel.visible = true
	workspace.visible = true
	if _if_else_scroll: _if_else_scroll.visible = false
	_refresh_palette(data.available_commands)

# ── IF-ELSE mode ───────────────────────────────────────────────────────────────
func _enter_if_else_mode(data: LevelData) -> void:
	$UI/CommandPalette.visible     = false
	$UI/BackspaceButton.visible    = false
	$UI/ActionCounterPanel.visible = false
	workspace.visible = false
	if _if_else_scroll: _if_else_scroll.visible = true

	# Clear previous blueprint widgets
	for child in _if_else_workspace.get_children():
		child.queue_free()
	_if_else_blocks.clear()

	# Look up blueprint from BLUEPRINTS table using the level name
	var blueprint : Array = BLUEPRINTS.get(data.level_name, [])
	for block_def in blueprint:
		var widget : RepeatIfElseBlock = RepeatIfElseBlock.new()
		widget.repeat_count    = block_def.get("repeat_count",    6)
		widget.check_direction = _blueprint_val(block_def.get("check_direction", "?"))
		widget.check_condition = _blueprint_val(block_def.get("check_condition", "?"))
		widget.then_action     = _blueprint_val(block_def.get("then_action",     "?"))
		widget.else_action     = _blueprint_val(block_def.get("else_action",     "?"))
		_if_else_workspace.add_child(widget)
		_if_else_blocks.append(widget)

	if _if_else_blocks.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No blueprint found for: " + data.level_name
		placeholder.add_theme_color_override("font_color", Color.YELLOW)
		_if_else_workspace.add_child(placeholder)

# Returns null (blank dropdown) if value is "?" sentinel, otherwise returns the value as-is.
func _blueprint_val(val: Variant) -> Variant:
	if val == "?": return null
	return val

# ── Execution ──────────────────────────────────────────────────────────────────
func _on_run_pressed() -> void:
	if is_executing: return
	_pending_mode = PendingMode.NONE
	_clear_palette_hint()
	is_executing          = true
	_level_complete       = false
	current_command_index = 0
	total_actions_taken   = 0
	run_button.disabled   = true

	if _is_if_else_mode:
		_execute_if_else_program()
	else:
		if command_blocks.is_empty():
			is_executing = false; run_button.disabled = false; return
		_execute_next()

# IF-ELSE execution: build CommandBlocks from widgets and run them
func _execute_if_else_program() -> void:
	var cbs : Array[CommandBlock] = []
	for widget in _if_else_blocks:
		if widget is RepeatIfElseBlock:
			cbs.append(widget.build_command_block())

	if cbs.is_empty():
		is_executing = false; run_button.disabled = false; return

	robot.set_meta("level_done", false)

	for cb in cbs:
		if _level_complete: break
		await cb.execute(robot)
		await get_tree().create_timer(0.2).timeout

	for cb in cbs: cb.queue_free()

	if not _level_complete:
		_on_program_finished_if_else()
	else:
		is_executing = false

func _on_program_finished_if_else() -> void:
	is_executing = false
	_show_failure_flash()
	await get_tree().create_timer(1.0).timeout
	var data : LevelData = load(levels[current_level_index]) as LevelData
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	total_actions_taken   = 0
	current_command_index = 0
	run_button.disabled   = false
	robot.set_meta("level_done", false)

# Standard execution — fully awaited chain, no signal re-entry issues
func _execute_next() -> void:
	if current_command_index >= command_blocks.size():
		_on_program_finished(); return
	var cmd : CommandBlock = command_blocks[current_command_index]
	_highlight(cmd)
	total_actions_taken += 1
	block_manager.on_action_taken(total_actions_taken)
	current_command_index += 1
	await cmd.execute(robot)           # await here — robot emits action_completed when done
	if not is_executing: return        # level may have completed mid-command
	await get_tree().create_timer(0.15).timeout
	_execute_next()

# action_completed is still emitted by the robot but we no longer use it to drive
# the execution loop — _execute_next() awaits directly. Kept for compatibility.
func _on_action_completed() -> void:
	pass

func _on_program_finished() -> void:
	is_executing = false
	_clear_highlights()
	if _level_complete: return
	_show_failure_flash()
	await get_tree().create_timer(1.0).timeout
	var data : LevelData = load(levels[current_level_index]) as LevelData
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	_pending_mode         = PendingMode.NONE
	total_actions_taken   = 0
	current_command_index = 0
	run_button.disabled   = false
	_update_counter()
	_clear_palette_hint()

func _on_level_complete() -> void:
	_level_complete     = true
	is_executing        = false
	run_button.disabled = true
	_clear_highlights()
	robot.set_meta("level_done", true)
	_show_level_complete_popup()

func _show_level_complete_popup() -> void:
	var popup = LevelCompleteScreen.instantiate()
	$UI.add_child(popup)
	popup.next_level_pressed.connect(func():
		popup.queue_free()
		current_level_index += 1
		_load_level(current_level_index))

func _show_win_screen() -> void:
	print("ALL LEVELS COMPLETE!")

# ── Standard palette handlers ──────────────────────────────────────────────────
func _on_loop_pressed() -> void:
	if is_executing: return
	if _pending_mode == PendingMode.LOOP:
		_pending_mode = PendingMode.NONE; _clear_palette_hint(); return
	_pending_mode = PendingMode.LOOP
	_set_palette_hint("Pick action to loop ×3…")

func _on_append_pressed() -> void:
	if is_executing: return
	if _pending_mode in [PendingMode.APPEND_FIRST, PendingMode.APPEND_SECOND]:
		_pending_mode = PendingMode.NONE; _clear_palette_hint(); return
	_pending_mode = PendingMode.APPEND_FIRST
	_set_palette_hint("Pick FIRST action…")

func _on_basic_pressed(cmd_type: CommandBlock.CommandType) -> void:
	if is_executing: return
	match _pending_mode:
		PendingMode.NONE:      _add_basic_cmd(cmd_type)
		PendingMode.LOOP:
			var block := CommandBlock.new(CommandBlock.CommandType.LOOP)
			block.loop_action = cmd_type
			_finalise_block(block)
			_pending_mode = PendingMode.NONE; _clear_palette_hint()
		PendingMode.APPEND_FIRST:
			_pending_first_action = cmd_type
			_pending_mode         = PendingMode.APPEND_SECOND
			_set_palette_hint("Pick SECOND action…")
		PendingMode.APPEND_SECOND:
			var block := CommandBlock.new(CommandBlock.CommandType.APPEND)
			block.first_action  = _pending_first_action
			block.second_action = cmd_type
			_finalise_block(block)
			_pending_mode = PendingMode.NONE; _clear_palette_hint()

func _finalise_block(block: CommandBlock) -> void:
	if command_blocks.size() >= max_actions:
		block.queue_free(); _flash_error(); return
	workspace.add_child(block)
	command_blocks.append(block)
	block.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_remove_cmd(block))
	_update_counter()

func _add_basic_cmd(cmd_type: CommandBlock.CommandType) -> void:
	_finalise_block(CommandBlock.new(cmd_type))

func _remove_cmd(block: CommandBlock) -> void:
	command_blocks.erase(block)
	workspace.remove_child(block)
	block.queue_free()
	_update_counter()

func _remove_last_cmd() -> void:
	if command_blocks.is_empty(): return
	_remove_cmd(command_blocks.back())

func _clear_commands() -> void:
	for b in command_blocks: b.queue_free()
	command_blocks.clear()
	_update_counter()

func _refresh_palette(allowed: Array[String]) -> void:
	btn_up.visible     = allowed.has("up")
	btn_down.visible   = allowed.has("down")
	btn_left.visible   = allowed.has("left")
	btn_right.visible  = allowed.has("right")
	btn_attack.visible = allowed.has("attack")
	btn_loop.visible   = allowed.has("loop")
	btn_append.visible = allowed.has("append")

# ── Tutorial ───────────────────────────────────────────────────────────────────
func _show_tutorial(level_index: int) -> void:
	var steps := _get_tutorial_steps(level_index)
	# If no steps for this level, skip — never disable the run button
	if steps.is_empty():
		return
	var overlay = TutorialOverlay.instantiate()
	$UI.add_child(overlay)
	overlay.tutorial_finished.connect(func(): run_button.disabled = false)
	run_button.disabled = true
	overlay.setup(steps)

func _get_tutorial_steps(level_index: int) -> Array[Dictionary]:
	match level_index:
		0:
			return [
				{"text": "[b]Welcome![/b]\n\nYour robot slides until it hits a wall.", "pointer_pos": null},
				{"text": "Click commands to build your program.", "pointer_pos": Vector2(97, 200)},
				{"text": "Commands appear in the workspace below.", "pointer_pos": Vector2(500, 530)},
				{"text": "Press RUN to execute.", "pointer_pos": Vector2(940, 610)},
				{"text": "Reach the EXIT tile!", "pointer_pos": Vector2(850, 300)},
			]
		1:
			return [
				{"text": "These cracked blocks can be broken with ATTACK.", "pointer_pos": Vector2(580, 390)},
				{"text": "Use ATTACK to reduce a block's HP to zero.", "pointer_pos": Vector2(97, 290)},
			]
		2:
			return [
				{"text": "Even blocks open on even-numbered actions.", "pointer_pos": Vector2(850, 197)},
				{"text": "Odd blocks open on odd-numbered actions.", "pointer_pos": Vector2(850, 420)},
			]
		6:
			return [
				{"text": "[b]New: REPEAT-IF-ELSE![/b]\n\nYou now have a blueprint — fill in the blank dropdowns.", "pointer_pos": null},
				{"text": "Pick a direction to sense and whether it's free or blocked.", "pointer_pos": null},
				{"text": "THEN runs when the condition is true. ELSE runs otherwise.", "pointer_pos": null},
				{"text": "The robot now moves ONE tile per step — no more sliding.", "pointer_pos": null},
			]
	return []

# ── UI helpers ─────────────────────────────────────────────────────────────────
func _set_palette_hint(msg: String) -> void:
	var lbl = get_node_or_null("UI/CommandPalette/HintLabel")
	if lbl: lbl.text = msg
	btn_loop.modulate   = Color.YELLOW if _pending_mode == PendingMode.LOOP else Color.WHITE
	btn_append.modulate = Color.CYAN   if _pending_mode in [PendingMode.APPEND_FIRST, PendingMode.APPEND_SECOND] else Color.WHITE

func _clear_palette_hint() -> void:
	var lbl = get_node_or_null("UI/CommandPalette/HintLabel")
	if lbl: lbl.text = ""
	btn_loop.modulate   = Color.WHITE
	btn_append.modulate = Color.WHITE

func _highlight(cmd: CommandBlock) -> void:
	_clear_highlights(); cmd.modulate = Color.YELLOW

func _clear_highlights() -> void:
	for cmd in command_blocks: cmd.modulate = Color.WHITE

func _update_counter() -> void:
	if _is_if_else_mode: return
	var n : int = command_blocks.size()
	count_label.text = "%d / %d" % [n, max_actions]
	count_label.add_theme_color_override("font_color",
		Color.GREEN if n < max_actions else Color.YELLOW)

func _show_failure_flash() -> void:
	if count_label and not _is_if_else_mode:
		count_label.add_theme_color_override("font_color", Color.RED)
		count_label.text = "RESET!"
	for cmd in command_blocks: cmd.modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	for cmd in command_blocks: cmd.modulate = Color.WHITE

func _flash_error() -> void:
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	_update_counter()
