extends Node2D

const TutorialOverlay = preload("res://scenes/tutorial_overlay.tscn")

@onready var robot         : Robot         = $GameWorld/Robot
@onready var block_manager : BlockManager  = $GameWorld/BlockManager
@onready var workspace     : HBoxContainer = $UI/WorkspacePanel/Workspace
@onready var run_button    : Button        = $UI/RunButton
@onready var count_label   : Label         = $UI/ActionCounterPanel/VBoxContainer/CountLabel
@onready var title_label   : Label         = $UI/ActionCounterPanel/VBoxContainer/TitleLabel

@onready var btn_up     : Button = $UI/CommandPalette/UpButton
@onready var btn_down   : Button = $UI/CommandPalette/DownButton
@onready var btn_left   : Button = $UI/CommandPalette/LeftButton
@onready var btn_right  : Button = $UI/CommandPalette/RightButton
@onready var btn_attack : Button = $UI/CommandPalette/AttackButton
@onready var btn_loop   : Button = $UI/CommandPalette/LoopButton
@onready var btn_append : Button = $UI/CommandPalette/AppendButton

@export var levels : Array[String] = [
	"res://levels/level_1.tres",
	"res://levels/level_2.tres",
	"res://levels/level_3.tres",
	"res://levels/level_4.tres",
	"res://levels/level_5.tres"
]

var current_level_index   : int  = 0
var command_blocks        : Array[CommandBlock] = []
var is_executing          : bool = false
var current_command_index : int  = 0
var total_actions_taken   : int  = 0
var max_actions           : int  = 8
var _level_complete       : bool = false

# Tracks which levels have already shown their tutorial — retries won't re-trigger
var _tutorial_seen : Array[bool] = [false, false, false]

# ── Pending modifier state ─────────────────────────────────────────────────────
enum PendingMode { NONE, LOOP, APPEND_FIRST, APPEND_SECOND }
var _pending_mode         : PendingMode = PendingMode.NONE
var _pending_first_action : CommandBlock.CommandType = CommandBlock.CommandType.MOVE_UP

# ── Help panel references (built in code, no scene edits needed) ───────────────
var _help_panel  : PanelContainer = null
var _help_button : Button         = null

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
	robot.action_completed.connect(_on_action_completed)
	block_manager.level_complete.connect(_on_level_complete)
	robot.block_manager = block_manager

	_build_help_ui()
	_load_level(current_level_index)

# ── Help UI (built entirely in code — no scene changes needed) ─────────────────
func _build_help_ui() -> void:
	var ui_layer = $UI

	# Small "?" button pinned to the vertical centre of the right edge
	_help_button = Button.new()
	_help_button.text = "?"
	_help_button.custom_minimum_size = Vector2(36, 36)
	_help_button.anchor_left   = 1.0
	_help_button.anchor_right  = 1.0
	_help_button.anchor_top    = 0.5
	_help_button.anchor_bottom = 0.5
	_help_button.offset_left   = -50.0
	_help_button.offset_right  = -14.0
	_help_button.offset_top    = -18.0
	_help_button.offset_bottom =  18.0
	_help_button.add_theme_font_size_override("font_size", 20)
	ui_layer.add_child(_help_button)
	_help_button.pressed.connect(_on_help_pressed)

	# Pop-up panel that appears to the left of the "?" button
	_help_panel = PanelContainer.new()
	_help_panel.anchor_left   = 1.0
	_help_panel.anchor_right  = 1.0
	_help_panel.anchor_top    = 0.5
	_help_panel.anchor_bottom = 0.5
	_help_panel.offset_left   = -310.0
	_help_panel.offset_right  =  -52.0
	_help_panel.offset_top    = -160.0
	_help_panel.offset_bottom =  160.0

	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.10, 0.10, 0.16, 0.97)
	style.border_width_left          = 2
	style.border_width_right         = 2
	style.border_width_top           = 2
	style.border_width_bottom        = 2
	style.border_color               = Color(0.40, 0.40, 0.70, 1.0)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	_help_panel.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   12)
	margin.add_theme_constant_override("margin_right",  12)
	margin.add_theme_constant_override("margin_top",    10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_help_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Panel title
	var title := Label.new()
	title.text = "Move List"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# One entry per command
	var entries : Array = [
		["↑  ↓  ←  →",  "Move the robot. It slides\nuntil it hits a wall."],
		["⚔  ATTACK",    "Break the block in front\nof the robot (−1 HP)."],
		["↺  LOOP ×3",   "Choose any action — it\nrepeats 3 times, uses 1 slot."],
		["&&  APPEND",   "Chain two actions into\n1 slot. Both run in order."],
	]

	for entry in entries:
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		vbox.add_child(row)

		var cmd_lbl := Label.new()
		cmd_lbl.text = entry[0]
		cmd_lbl.add_theme_font_size_override("font_size", 14)
		cmd_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		row.add_child(cmd_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = entry[1]
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1.0))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(desc_lbl)

		# Small spacer between entries
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 4)
		vbox.add_child(spacer)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(func(): _help_panel.visible = false)
	vbox.add_child(close_btn)

	_help_panel.visible = false
	ui_layer.add_child(_help_panel)

func _on_help_pressed() -> void:
	_help_panel.visible = not _help_panel.visible

# ── Modifier button handlers ───────────────────────────────────────────────────

func _on_loop_pressed() -> void:
	if is_executing: return
	_pending_mode = PendingMode.LOOP
	_set_palette_hint("Pick action to loop ×3…")

func _on_append_pressed() -> void:
	if is_executing: return
	_pending_mode = PendingMode.APPEND_FIRST
	_set_palette_hint("Pick FIRST action…")

func _on_basic_pressed(cmd_type: CommandBlock.CommandType) -> void:
	if is_executing: return

	match _pending_mode:
		PendingMode.NONE:
			_add_basic_cmd(cmd_type)

		PendingMode.LOOP:
			var block := CommandBlock.new(CommandBlock.CommandType.LOOP)
			block.loop_action = cmd_type
			_finalise_block(block)
			_pending_mode = PendingMode.NONE
			_clear_palette_hint()

		PendingMode.APPEND_FIRST:
			_pending_first_action = cmd_type
			_pending_mode         = PendingMode.APPEND_SECOND
			_set_palette_hint("Pick SECOND action…")

		PendingMode.APPEND_SECOND:
			var block := CommandBlock.new(CommandBlock.CommandType.APPEND)
			block.first_action  = _pending_first_action
			block.second_action = cmd_type
			_finalise_block(block)
			_pending_mode = PendingMode.NONE
			_clear_palette_hint()

func _finalise_block(block: CommandBlock) -> void:
	if command_blocks.size() >= max_actions:
		block.queue_free()
		_flash_error()
		return
	workspace.add_child(block)
	command_blocks.append(block)
	block.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_remove_cmd(block))
	_update_counter()

func _add_basic_cmd(cmd_type: CommandBlock.CommandType) -> void:
	var block := CommandBlock.new(cmd_type)
	_finalise_block(block)

# ── Palette hint label ─────────────────────────────────────────────────────────
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

# ── Level loading ──────────────────────────────────────────────────────────────
func _load_level(index: int) -> void:
	if index >= levels.size():
		_show_win_screen()
		return
	var data : LevelData = load(levels[index]) as LevelData
	if data == null:
		push_error("Could not load: " + levels[index])
		return
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
	_update_counter()
	_clear_palette_hint()

	# Only show tutorial the FIRST time a level loads — retries skip it
	if index < _tutorial_seen.size() and not _tutorial_seen[index]:
		_tutorial_seen[index] = true
		_show_tutorial(index)

func _reload_current_level() -> void:
	# _tutorial_seen[current_level_index] is already true, so tutorial won't fire
	_load_level(current_level_index)

# ── Tutorial ───────────────────────────────────────────────────────────────────
func _show_tutorial(level_index: int) -> void:
	var overlay = TutorialOverlay.instantiate()
	$UI.add_child(overlay)
	overlay.setup(_get_tutorial_steps(level_index))
	overlay.tutorial_finished.connect(func():
		run_button.disabled = false)
	run_button.disabled = true

func _get_tutorial_steps(level_index: int) -> Array[Dictionary]:
	match level_index:
		0: # Level 1 — basic movement
			return [
				{
					"text": "[b]Welcome![/b]\n\nYOUR TEXT HERE — introduce the game concept.",
					"pointer_pos": null
				},
				{
					"text": "YOUR TEXT HERE — explain the movement buttons.\n\nClick them to add commands to your program.",
					"pointer_pos": Vector2(97, 200)
				},
				{
					"text": "YOUR TEXT HERE — explain the workspace at the bottom.\n\nCommands you add appear here.",
					"pointer_pos": Vector2(500, 530)
				},
				{
					"text": "YOUR TEXT HERE — explain the Run button.",
					"pointer_pos": Vector2(940, 610)
				},
				{
					"text": "YOUR TEXT HERE — explain the goal: reach the EXIT tile.",
					"pointer_pos": Vector2(850, 300)
				},
			]
		1: # Level 2 — collapsible blocks
			return [
				{
					"text": "YOUR TEXT HERE — introduce the white cracked blocks.",
					"pointer_pos": Vector2(580, 390)
				},
				{
					"text": "YOUR TEXT HERE — explain the ATTACK command.",
					"pointer_pos": Vector2(97, 290)
				},
			]
		2: # Level 3 — even/odd blocks
			return [
				{
					"text": "YOUR TEXT HERE — explain Even blocks.",
					"pointer_pos": Vector2(850, 197)
				},
				{
					"text": "YOUR TEXT HERE — explain Odd blocks.",
					"pointer_pos": Vector2(850, 420)
				},
			]
	return []

# ── Commands ───────────────────────────────────────────────────────────────────
func _remove_cmd(block: CommandBlock) -> void:
	command_blocks.erase(block)
	workspace.remove_child(block)
	block.queue_free()
	_update_counter()

func _clear_commands() -> void:
	for b in command_blocks: b.queue_free()
	command_blocks.clear()
	_update_counter()

# ── Execution ──────────────────────────────────────────────────────────────────
func _on_run_pressed() -> void:
	if is_executing or command_blocks.is_empty(): return
	_pending_mode = PendingMode.NONE
	_clear_palette_hint()
	is_executing          = true
	_level_complete       = false
	current_command_index = 0
	total_actions_taken   = 0
	run_button.disabled   = true
	_execute_next()

func _execute_next() -> void:
	if current_command_index >= command_blocks.size():
		_on_program_finished()
		return
	var cmd : CommandBlock = command_blocks[current_command_index]
	_highlight(cmd)
	total_actions_taken += 1
	block_manager.on_action_taken(total_actions_taken)
	cmd.execute(robot)
	current_command_index += 1

func _on_action_completed() -> void:
	if not is_executing: return
	await get_tree().create_timer(0.15).timeout
	_execute_next()

func _on_program_finished() -> void:
	is_executing = false
	_clear_highlights()
	if _level_complete:
		return
	_show_failure_flash()
	await get_tree().create_timer(1.0).timeout
	_reload_current_level()

func _on_level_complete() -> void:
	_level_complete     = true
	is_executing        = false
	run_button.disabled = true
	_clear_highlights()
	await get_tree().create_timer(1.0).timeout
	current_level_index += 1
	_load_level(current_level_index)

func _show_win_screen() -> void:
	print("ALL LEVELS COMPLETE!")

func _show_failure_flash() -> void:
	if count_label:
		count_label.add_theme_color_override("font_color", Color.RED)
		count_label.text = "RESET!"
	for cmd in command_blocks: cmd.modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	for cmd in command_blocks: cmd.modulate = Color.WHITE

# ── UI helpers ─────────────────────────────────────────────────────────────────
func _highlight(cmd: CommandBlock) -> void:
	_clear_highlights()
	cmd.modulate = Color.YELLOW

func _clear_highlights() -> void:
	for cmd in command_blocks: cmd.modulate = Color.WHITE

func _update_counter() -> void:
	var n : int = command_blocks.size()
	count_label.text = "%d / %d" % [n, max_actions]
	count_label.add_theme_color_override("font_color",
		Color.GREEN if n < max_actions else Color.YELLOW)

func _flash_error() -> void:
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	_update_counter()
