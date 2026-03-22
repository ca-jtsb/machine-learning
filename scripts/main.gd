extends Node2D

const TutorialOverlay     = preload("res://scenes/tutorial_overlay.tscn")
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
	"res://levels/level_1.tres",
	"res://levels/level_2.tres",
	"res://levels/level_3.tres",
	"res://levels/level_4.tres",
	"res://levels/level_5.tres",
	"res://levels/level_6.tres",
	"res://levels/level_7.tres",
	"res://levels/level_8.tres",
	"res://levels/level_9.tres",
	"res://levels/level_10.tres",
]

const IF_ELSE_UNLOCK_FROM_LEVEL : int = 0

# ── Blueprint definitions ─────────────────────────────────────────────────────
# "?" = blank dropdown. All other string values are pre-filled (read-only).
# compound_condition / compound_then / compound_else keys enable && in those slots.
const BLUEPRINTS : Dictionary = {
	"Level 7 - The Algorithm": [
		{ "repeat_count": 1,  "check_direction": "?", "check_condition": "?", "then_action": "?", "else_action": "?" },
		{ "repeat_count": 1, "check_direction": "?", "check_condition": "?", "then_action": "?", "else_action": "?" },
	],
	"Level 8": [
		{ "repeat_count": 1, "check_direction": "RIGHT", "check_condition": "is_obstacle", "then_action": "attack", "else_action": "move_right" },
	],

	# ── Level 9: ALL blank — player fills direction, condition, and actions ──────
	"Level 9": [
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
	],

	# ── Level 9 ALT: introduced after solving, shows && condition ──────────────
	"Level 9 - Alt": [
		{
			"repeat_count": 1,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "move_up",
			"else_action": "move_right", "compound_else": true, "else_action2": "attack",
			"else2_attack_dir": "RIGHT"
		},
	],

	# ── Level 10: player fills blank slots ─────────────────────────────────────
	"Level 10": [
		{
			"repeat_count": 1,
			"check_direction": "RIGHT", "check_condition": "is_free",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"then_action": "attack", "then_attack_dir": "RIGHT",
			"compound_then": true, "then_action2": "move_right",
			"else_action": "move_right"
		},
		{
			"repeat_count": 1,
			"check_direction": "DOWN", "check_condition": "is_free",
			"then_action": "move_down",
			"else_action": "move_left"
		},
	],

	# ── "Final Level" alias — matches level_name in level_10.tres ──────────────
	# If your .tres uses level_name = "Final Level", this entry handles it.
	# If your .tres uses "Level 10", the entry above handles it. Keep both.
	"Final Level": [
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
	],
	"Final Level - Alt": [
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"compound_condition": true, "check_direction2": "?", "check_condition2": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?", "then_attack_dir": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
	],

	# ── Level 10 ALT ──────────────────────────────────────────────────────────
	# Block 1: && condition teaches optimization — checks RIGHT==obstacle AND UP==free
	# to decide whether to go up (T-junction) or keep going right (corridor).
	# Block 2: attack RIGHT first, then step right — this order works because the
	# robot stays put while attacking, only moving forward once the block is gone.
	# Block 3: same as original — descend and exit.
	"Level 10 - Alt": [
		{
			"repeat_count": 7,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "move_up",
			"else_action": "move_right"
		},
		{
			"repeat_count": 8,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"then_action": "attack", "then_attack_dir": "RIGHT",
			"compound_then": true, "then_action2": "move_right",
			"else_action": "move_right"
		},
		{
			"repeat_count": 5,
			"check_direction": "DOWN", "check_condition": "is_free",
			"then_action": "move_down",
			"else_action": "move_left"
		},
	],
}

# ── Alt-solution config: which levels show alt after solving ───────────────────
# Key = level_name, value = { "hint": text, "alt_key": BLUEPRINTS key to show }
const ALT_SOLUTIONS : Dictionary = {
	"Level 9": {
		"hint": "Great work! But did you know you can combine conditions with [b]&&[/b]?\nThat lets you check TWO directions at once — reducing your blocks from 2 down to 1!",
		"alt_key": "Level 9 - Alt"
	},
	"Level 10": {
		"hint": "Excellent! Notice Block 1 used [b]RIGHT == isFree && UP == isFree[/b].\nHere's an alternative — using [b]RIGHT == isObstacle && UP == isFree[/b] instead.\nSame result, different way to think about it!",
		"alt_key": "Level 10 - Alt"
	},
	"Final Level": {
		"hint": "Excellent! Notice Block 1 used [b]RIGHT == isFree && UP == isFree[/b].\nHere's an alternative — using [b]RIGHT == isObstacle && UP == isFree[/b] instead.\nSame result, different way to think about it!",
		"alt_key": "Final Level - Alt"
	},
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
var _current_level_name   : String = ""
var _showing_alt          : bool   = false   # suppresses level_complete popup during alt demo
var _hit_wall             : bool   = false   # set true when robot walks into wall in Phase 2 → triggers failure

# ── IF-ELSE blueprint widgets ──────────────────────────────────────────────────
var _if_else_blocks    : Array            = []
var _if_else_workspace : VBoxContainer   = null
var _if_else_scroll    : ScrollContainer = null
var _if_else_panel     : PanelContainer  = null

# ── Pending modifier state ─────────────────────────────────────────────────────
enum PendingMode { NONE, LOOP, APPEND_FIRST, APPEND_SECOND }
var _pending_mode         : PendingMode = PendingMode.NONE
var _pending_first_action : CommandBlock.CommandType = CommandBlock.CommandType.MOVE_UP

# ── Help panel ─────────────────────────────────────────────────────────────────
var _help_panel  : PanelContainer = null
var _help_button : Button         = null

# ── Layout constants ───────────────────────────────────────────────────────────
const GRID_X_STANDARD    : float = 168.0
const GRID_X_IF_ELSE     : float = 16.0
const GRID_Y             : float = 8.0
const IFELSE_PANEL_X     : float = 816.0
const IFELSE_PANEL_RIGHT : float = 1146.0
const IFELSE_PANEL_TOP   : float = 8.0
const IFELSE_PANEL_BOTTOM : float = -112.0

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
	robot.hit_wall.connect(_on_hit_wall)
	block_manager.level_complete.connect(_on_level_complete)
	robot.block_manager = block_manager

	_tutorial_seen.resize(levels.size())
	_tutorial_seen.fill(false)

	_build_help_ui()
	_build_if_else_workspace()
	_load_level(current_level_index)

# ── IF-ELSE right-side panel ───────────────────────────────────────────────────
func _build_if_else_workspace() -> void:
	var ui_layer = $UI
	var panel := PanelContainer.new()
	panel.name          = "IfElsePanel"
	panel.anchor_left   = 0.0; panel.anchor_right  = 0.0
	panel.anchor_top    = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left   = IFELSE_PANEL_X
	panel.offset_right  = IFELSE_PANEL_RIGHT
	panel.offset_top    = IFELSE_PANEL_TOP
	panel.offset_bottom = IFELSE_PANEL_BOTTOM
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.08, 0.12, 1.0)
	style.border_color = Color(0.95, 0.55, 0.05, 1.0)
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	ui_layer.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	_if_else_scroll = ScrollContainer.new()
	_if_else_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_if_else_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(_if_else_scroll)

	_if_else_workspace = VBoxContainer.new()
	_if_else_workspace.add_theme_constant_override("separation", 12)
	_if_else_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_if_else_scroll.add_child(_if_else_workspace)

	_if_else_panel = panel

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
	_help_panel.offset_left = -310.0; _help_panel.offset_right = -52.0
	_help_panel.offset_top  = -200.0; _help_panel.offset_bottom = 200.0
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.10, 0.16, 0.97)
	style.border_color = Color(0.40, 0.40, 0.70, 1.0)
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 2)
	style.corner_radius_top_left = 6; style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	_help_panel.add_theme_stylebox_override("panel", style)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12 if side in ["left","right"] else 10)
	_help_panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)
	var title := Label.new(); title.text = "Commands"
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

	max_actions            = data.action_limit
	_level_complete        = false
	_current_level_name    = data.level_name
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
	$UI/RunButton.visible          = true
	$UI/ActionCounterPanel.visible = true
	$UI/WorkspacePanel.visible     = true
	workspace.visible              = true
	if _if_else_panel: _if_else_panel.visible = false
	$GameWorld.position = Vector2(GRID_X_STANDARD, GRID_Y)
	_refresh_palette(data.available_commands)

# ── IF-ELSE mode ───────────────────────────────────────────────────────────────
func _enter_if_else_mode(data: LevelData) -> void:
	$UI/CommandPalette.visible     = false
	$UI/BackspaceButton.visible    = true
	$UI/RunButton.visible          = true
	$UI/ActionCounterPanel.visible = false
	$UI/WorkspacePanel.visible     = false
	workspace.visible              = false
	if _if_else_panel: _if_else_panel.visible = true
	$GameWorld.position = Vector2(GRID_X_IF_ELSE, GRID_Y)
	_populate_blueprint(data.level_name)

func _populate_blueprint(level_name: String) -> void:
	for child in _if_else_workspace.get_children():
		child.queue_free()
	_if_else_blocks.clear()

	var blueprint : Array = BLUEPRINTS.get(level_name, [])
	if blueprint.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No blueprint for: " + level_name
		placeholder.add_theme_color_override("font_color", Color.YELLOW)
		_if_else_workspace.add_child(placeholder)
		return

	for block_def in blueprint:
		var widget : RepeatIfElseBlock = _make_widget_from_def(block_def)
		_if_else_workspace.add_child(widget)
		_if_else_blocks.append(widget)

func _make_widget_from_def(block_def: Dictionary) -> RepeatIfElseBlock:
	var w : RepeatIfElseBlock = RepeatIfElseBlock.new()
	w.repeat_count    = block_def.get("repeat_count", 6)
	w.check_direction = _bval(block_def.get("check_direction", "?"))
	w.check_condition = _bval(block_def.get("check_condition", "?"))
	w.use_compound_condition = block_def.get("compound_condition", false)
	w.check_direction2 = _bval(block_def.get("check_direction2", "?"))
	w.check_condition2 = _bval(block_def.get("check_condition2", "?"))
	w.then_action      = _bval(block_def.get("then_action", "?"))
	w.use_compound_then = block_def.get("compound_then", false)
	w.then_action2      = _bval(block_def.get("then_action2", "?"))
	w.else_action      = _bval(block_def.get("else_action", "?"))
	w.use_compound_else = block_def.get("compound_else", false)
	w.else_action2      = _bval(block_def.get("else_action2", "?"))
	# Attack direction overrides — "" means use current facing direction
	w.then_attack_dir  = block_def.get("then_attack_dir",  "")
	w.then2_attack_dir = block_def.get("then2_attack_dir", "")
	w.else_attack_dir  = block_def.get("else_attack_dir",  "")
	w.else2_attack_dir = block_def.get("else2_attack_dir", "")
	return w

func _bval(val: Variant) -> Variant:
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
		_hit_wall = false
		_execute_if_else_program()
	else:
		if command_blocks.is_empty():
			is_executing = false; run_button.disabled = false; return
		_execute_next()

func _execute_if_else_program() -> void:
	var cbs : Array[CommandBlock] = []
	for widget in _if_else_blocks:
		if widget is RepeatIfElseBlock:
			cbs.append(widget.build_command_block())

	if cbs.is_empty():
		is_executing = false; run_button.disabled = false; return

	robot.set_meta("level_done", false)

	for cb in cbs:
		if _level_complete or _hit_wall: break
		await cb.execute(robot)
		if _hit_wall: break
		await get_tree().create_timer(0.2).timeout

	for cb in cbs: cb.queue_free()

	if _hit_wall:
		_on_hit_wall_failure()
	elif not _level_complete:
		_on_program_finished_if_else()
	else:
		is_executing = false

func _on_hit_wall_failure() -> void:
	# Overlay was already shown by _on_hit_wall — nothing to do here.
	# The retry button in the overlay handles the reset.
	pass

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

func _execute_next() -> void:
	if current_command_index >= command_blocks.size():
		_on_program_finished(); return
	var cmd : CommandBlock = command_blocks[current_command_index]
	_highlight(cmd)
	total_actions_taken += 1
	block_manager.on_action_taken(total_actions_taken)
	current_command_index += 1
	await cmd.execute(robot)
	if not is_executing: return
	await get_tree().create_timer(0.15).timeout
	_execute_next()

func _on_action_completed() -> void:
	pass

func _on_hit_wall() -> void:
	# Only matters during Phase 2 execution
	if not _is_if_else_mode: return
	if not is_executing: return
	if _hit_wall: return   # already handling it
	_hit_wall    = true
	is_executing = false
	run_button.disabled = true
	# Show overlay immediately — don't wait for the loop to finish
	_show_wall_hit_overlay()

func _show_wall_hit_overlay() -> void:
	# Dim panel
	var dim := ColorRect.new()
	dim.name = "WallHitDim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(dim)

	# Popup panel
	var panel := PanelContainer.new()
	panel.name = "WallHitPanel"
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -260.0; panel.offset_right  = 260.0
	panel.offset_top    = -100.0; panel.offset_bottom = 100.0
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.06, 0.06, 1.0)
	style.border_color = Color(0.85, 0.15, 0.15, 1.0)
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 3)
	style.corner_radius_top_left    = 8; style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	$UI.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🚧  Hit a Wall!"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "The robot overshot and hit a wall.\nCount your steps more carefully and try again."
	msg.add_theme_font_size_override("font_size", 15)
	msg.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var retry_btn := Button.new()
	retry_btn.text = "↺  Retry"
	retry_btn.add_theme_font_size_override("font_size", 16)
	retry_btn.custom_minimum_size = Vector2(140, 44)
	retry_btn.pressed.connect(func():
		dim.queue_free()
		panel.queue_free()
		_hit_wall = false
		var data : LevelData = load(levels[current_level_index]) as LevelData
		block_manager.load_level(data)
		robot.reset_to(data.player_start)
		robot.set_meta("level_done", false)
		_level_complete = false
		run_button.disabled = false
	)
	vbox.add_child(retry_btn)

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

# ── Level complete flow ────────────────────────────────────────────────────────
func _on_level_complete() -> void:
	_level_complete     = true
	is_executing        = false
	run_button.disabled = true
	_clear_highlights()
	robot.set_meta("level_done", true)

	# During alt demo: reveal Continue button then reset so player can run again
	if _showing_alt:
		# Reveal the Continue button now that they've seen the alt work
		var cont = _if_else_workspace.get_node_or_null("AltContinueBtn")
		if cont: cont.visible = true
		var hint = _if_else_workspace.get_node_or_null("AltHintLabel")
		if hint: hint.visible = false
		await get_tree().create_timer(0.8).timeout
		var data : LevelData = load(levels[current_level_index]) as LevelData
		block_manager.load_level(data)
		robot.reset_to(data.player_start)
		robot.set_meta("level_done", false)
		_level_complete = false
		run_button.disabled = false
		return

	# Check if this level has an alt-solution to show before proceeding
	if ALT_SOLUTIONS.has(_current_level_name):
		_show_alt_solution_flow(_current_level_name)
	else:
		_show_level_complete_popup()

# ── Alt-solution flow ──────────────────────────────────────────────────────────
func _show_alt_solution_flow(level_name: String) -> void:
	var alt_info : Dictionary = ALT_SOLUTIONS[level_name]
	var hint_text : String    = alt_info["hint"]
	var alt_key   : String    = alt_info["alt_key"]

	# Show assistant hint overlay
	_show_assistant_overlay(hint_text, func():
		# After hint dismissed → load alt blueprint into panel
		_load_alt_blueprint(alt_key, func():
			# After alt demo → normal level complete popup
			_show_level_complete_popup()
		)
	)

func _show_assistant_overlay(text: String, on_done: Callable) -> void:
	# Reuse TutorialOverlay with a single step
	var overlay = TutorialOverlay.instantiate()
	$UI.add_child(overlay)
	overlay.tutorial_finished.connect(func():
		on_done.call()
	)
	var steps : Array[Dictionary] = [{"text": text, "pointer_pos": null}]
	overlay.setup(steps)

func _load_alt_blueprint(alt_key: String, on_done: Callable) -> void:
	_showing_alt = true   # suppress level_complete popup while alt is running

	# Clear previous blueprint widgets
	for child in _if_else_workspace.get_children():
		child.queue_free()
	_if_else_blocks.clear()

	# Load alt blueprint blocks (all pre-filled, read-only)
	var blueprint : Array = BLUEPRINTS.get(alt_key, [])
	for block_def in blueprint:
		var widget := _make_widget_from_def(block_def)
		_if_else_workspace.add_child(widget)
		_if_else_blocks.append(widget)

	# Separator + Continue button — hidden until player runs the alt at least once
	var sep := HSeparator.new()
	sep.name = "AltSeparator"
	_if_else_workspace.add_child(sep)

	var continue_btn := Button.new()
	continue_btn.name    = "AltContinueBtn"
	continue_btn.text    = "▶  Continue to Next Level"
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.custom_minimum_size = Vector2(0, 44)
	continue_btn.visible = false   # hidden until alt is run successfully
	continue_btn.pressed.connect(func():
		_showing_alt = false
		on_done.call()
	)
	_if_else_workspace.add_child(continue_btn)

	var hint_lbl := Label.new()
	hint_lbl.name = "AltHintLabel"
	hint_lbl.text = "Run the program above to continue!"
	hint_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_if_else_workspace.add_child(hint_lbl)

	# Ensure panel is visible (handles case where level was standard-mode)
	if _if_else_panel and not _if_else_panel.visible:
		_if_else_panel.visible = true
		$GameWorld.position = Vector2(GRID_X_IF_ELSE, GRID_Y)

	# Reset the level so player can watch (or try) the alt solution
	var data : LevelData = load(levels[current_level_index]) as LevelData
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	robot.set_meta("level_done", false)
	_level_complete = false
	run_button.disabled = false
	# Player is now free to press RUN as many times as they like.
	# When ready, they click "Continue to Next Level" above.

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
	if steps.is_empty(): return
	var overlay = TutorialOverlay.instantiate()
	$UI.add_child(overlay)
	overlay.tutorial_finished.connect(func(): run_button.disabled = false)
	run_button.disabled = true
	overlay.setup(steps)

# ══════════════════════════════════════════════════════════════════════════════
# TUTORIAL STEPS — edit here to change dialogue, pointers, or box positions.
#
# Each step is a Dictionary with these keys:
#   "text"        — RichTextLabel BBCode string shown in the dialogue box.
#                   Use [b]bold[/b] for emphasis.
#   "pointer_pos" — Vector2 screen position the arrow points to.
#                   Set to null to hide the pointer entirely.
#   "box_pos"     — (optional) Vector2 where the dialogue box appears.
#                   Defaults to DEFAULT_POS in tutorial_overlay.gd (210, 300).
#   "box_size"    — (optional) Vector2 size of the dialogue box.
#                   Defaults to DEFAULT_SIZE in tutorial_overlay.gd (720, 160).
#
# Pointer reference positions (1152×648 screen, standard palette-left layout):
#   Palette buttons (up/dn/lt/rt/atk/loop/append): x≈80, y≈40/80/120/160/200/240/280
#   Grid center:      Vector2(576, 272)
#   Workspace panel:  Vector2(576, 590)
#   Action counter:   Vector2(1060, 30)
#   Run button:       Vector2(1064, 624)
#   Backspace button: Vector2(1064, 580)
#
# Phase 2 layout (palette hidden, grid at x=16, right panel x=816..1146):
#   REPEAT spinbox:   Vector2(920,  50)
#   IF row:           Vector2(920,  90)
#   THEN row:         Vector2(920, 120)
#   ELSE row:         Vector2(920, 150)
#   Right panel mid:  Vector2(980, 270)
#   Blank dropdowns:  Vector2(920, 100) approx — adjust per level
#
# To add a tutorial for a new level, add a new "N:" case below
# where N is the zero-based index in the levels[] array.
# ══════════════════════════════════════════════════════════════════════════════
func _get_tutorial_steps(level_index: int) -> Array[Dictionary]:
	match level_index:

		# ── LEVEL 1 (index 0) ─────────────────────────────────────────────────
		0:
			return [
				{
					"text": "[b]Hey there, fellow programmer![/b]\n\nOur company is about to release a groundbreaking system — but a cyberattack from our rivals has corrupted it. We need you to regain control!",
					"pointer_pos": null,
				},
				{
					"text": "Your goal is to create a sequence of movements for the robot to successfully reach the exit.",
					"pointer_pos": null,   # TODO: point to EXIT tile once its screen position is known
				},
				{
					"text": "These buttons are your controls. Moving [b]Up, Down, Left, or Right[/b] slides the robot in that direction until it hits a wall.",
					"pointer_pos": Vector2(80, 140),   # points at the movement buttons in the palette
				},
				{
					"text": "[b]&&  APPEND[/b] lets you combine two moves into a single action slot.",
					"pointer_pos": Vector2(80, 280),   # points at the Append button
				},
				{
					"text": "The moves you choose appear down here in the workspace, in the order they will run.",
					"pointer_pos": Vector2(576, 590),  # points at the workspace panel
				},
				{
					"text": "When you are ready, press [b]RUN PROGRAM[/b] to send your sequence to the robot.",
					"pointer_pos": Vector2(1064, 624), # points at the Run button
				},
				{
					"text": "Watch this counter carefully. Each level has an action limit — don't go over it!\n\nWe're counting on you. Good luck!",
					"pointer_pos": Vector2(1060, 30),  # points at the action counter top-right
				},
			]

		# ── LEVEL 2 (index 1) ─────────────────────────────────────────────────
		1:
			return [
				{
					"text": "Boxes are blocking the path! The number on each box shows how many hits it takes to break it.",
					"pointer_pos": Vector2(576, 272),  # TODO: point at a collapsible block on the grid
				},
				{
					"text": "Use [b]ATTACK[/b] to hit a box. You can also use [b]LOOP[/b] to hit it multiple times in one slot.",
					"pointer_pos": Vector2(80, 200),   # points at the Attack button in palette
				},
			]

		# ── LEVEL 3 (index 2) ─────────────────────────────────────────────────
		2:
			return [
				{
					"text": "[b]Even blocks[/b] only open when the action that reaches them is even-numbered — action 2, 4, 6, and so on.",
					"pointer_pos": null,   # TODO: point at an even block on this level's grid
				},
				{
					"text": "[b]Odd blocks[/b] open on odd-numbered actions — 1, 3, 5...\n\nPlan your sequence carefully so you have a clear path when you need it!",
					"pointer_pos": null,   # TODO: point at an odd block on this level's grid
				},
			]

		# ── LEVEL 4 (index 3) ─────────────────────────────────────────────────
		3:
			return [
				{
					"text": "Locked doors are blocking the path. Find the switch and step on it to unlock the door!",
					"pointer_pos": null,   # TODO: point at the lock or switch tile
				},
			]

		# ── LEVEL 7 (index 6) — Phase 2 introduction ──────────────────────────
		6:
			return [
				{
					"text": "Before you go further — the system is handing you something new.\n\nUp until now you've been pressing commands one by one. This sector is different. You'll be given a [b]blueprint[/b] — a program that's already half-written. Your job is to fill in the blanks.",
					"pointer_pos": null,
				},
				{
					"text": "See the [b]REPEAT[/b] block? It runs whatever is inside it N times in a row. Each time it runs, it checks the situation fresh.\n\nHere's the key difference: the robot now moves [b]exactly one tile per iteration[/b]. It does not slide.",
					"pointer_pos": Vector2(920, 50),   # points at the REPEAT header / spinbox
				},
				{
					"text": "Inside the repeat there is always an [b]IF[/b] and an [b]ELSE[/b].\n\nEvery iteration, the robot asks the IF question. If the answer is yes — it does the IF action. If no — it does the ELSE action. One or the other. Never both.",
					"pointer_pos": Vector2(920, 110),  # points at the IF/ELSE rows
				},
				{
					"text": "The condition always looks like: [b]direction == isFree[/b]\n\n[b]==[/b] means 'is equal to' — it is asking a question, not setting something.\n[b]isFree[/b] means the tile is passable. [b]isObstacle[/b] means it is blocked.",
					"pointer_pos": Vector2(920, 90),   # points at the IF condition row
				},
				{
					"text": "See the blank dropdowns? That's what you are filling in.\n\nThe structure is fixed. You choose what goes inside — the direction to check, the condition, and what action to take.",
					"pointer_pos": Vector2(920, 100),  # points at the blank dropdown area
				},
			]

		# ── LEVEL 9 (index 8) — first independent attempt ─────────────────────
		8:
			return [
				{
					"text": "[b]Your turn![/b]\n\nFill in all the blank dropdowns and hit RUN. You've seen how this works — now figure it out yourself!",
					"pointer_pos": Vector2(920, 100),  # points at blank dropdowns in right panel
				},
			]

		# ── Add new levels below this line ────────────────────────────────────
		# Example:
		# 9:  # Level 10 (index 9)
		#   return [
		#     { "text": "Your dialogue here.", "pointer_pos": Vector2(x, y) },
		#   ]

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
