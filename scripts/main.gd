extends Node2D

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

# ── Pending modifier state ─────────────────────────────────────────────────────
enum PendingMode { NONE, LOOP, APPEND_FIRST, APPEND_SECOND }
var _pending_mode        : PendingMode = PendingMode.NONE
var _pending_first_action : CommandBlock.CommandType = CommandBlock.CommandType.MOVE_UP

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

	_load_level(current_level_index)

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

func _reload_current_level() -> void:
	_load_level(current_level_index)

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
	# FIX: increment BEFORE executing so is_blocked sees the updated count
	total_actions_taken += 1
	block_manager.on_action_taken(total_actions_taken)
	cmd.execute(robot)
	current_command_index += 1

func _on_action_completed() -> void:
	if not is_executing: return
	# FIX: removed increment from here — it now happens in _execute_next
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
