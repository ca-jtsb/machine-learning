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

@export var levels : Array[String] = [
	"res://levels/level_1.tres",
	"res://levels/level_2.tres",
	"res://levels/level_3.tres",
]

var current_level_index : int = 0
var command_blocks        : Array[CommandBlock] = []
var is_executing          : bool = false
var current_command_index : int  = 0
var total_actions_taken   : int  = 0
var max_actions           : int  = 8

func _ready() -> void:
	# DO NOT offset GameWorld here — its position is set in the Godot editor
	# on the GameWorld node itself (Inspector → Position).
	# Set GameWorld Position to e.g. Vector2(210, 10) in the Inspector.

	btn_up.pressed.connect(func():     _add_cmd(CommandBlock.CommandType.MOVE_UP))
	btn_down.pressed.connect(func():   _add_cmd(CommandBlock.CommandType.MOVE_DOWN))
	btn_left.pressed.connect(func():   _add_cmd(CommandBlock.CommandType.MOVE_LEFT))
	btn_right.pressed.connect(func():  _add_cmd(CommandBlock.CommandType.MOVE_RIGHT))
	btn_attack.pressed.connect(func(): _add_cmd(CommandBlock.CommandType.ATTACK))

	run_button.pressed.connect(_on_run_pressed)
	robot.action_completed.connect(_on_action_completed)
	block_manager.level_complete.connect(_on_level_complete)
	robot.block_manager = block_manager

	_load_level(0)

func _load_level(index: int) -> void:
	if index >= levels.size():
		_show_win_screen()
		return
	var data : LevelData = load(levels[index]) as LevelData
	if data == null:
		push_error("Could not load: " + levels[index])
		return
	max_actions = data.action_limit
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	_clear_commands()
	total_actions_taken   = 0
	current_command_index = 0
	is_executing          = false
	run_button.disabled   = false
	if title_label: title_label.text = data.level_name
	_update_counter()

func _add_cmd(cmd_type: CommandBlock.CommandType) -> void:
	if command_blocks.size() >= max_actions:
		_flash_error()
		return
	var block := CommandBlock.new(cmd_type)
	workspace.add_child(block)
	command_blocks.append(block)
	block.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_remove_cmd(block))
	_update_counter()

func _remove_cmd(block: CommandBlock) -> void:
	command_blocks.erase(block)
	workspace.remove_child(block)
	block.queue_free()
	_update_counter()

func _clear_commands() -> void:
	for b in command_blocks: b.queue_free()
	command_blocks.clear()
	_update_counter()

func _on_run_pressed() -> void:
	if is_executing or command_blocks.is_empty(): return
	is_executing          = true
	current_command_index = 0
	total_actions_taken   = 0
	run_button.disabled   = true
	_execute_next()

func _execute_next() -> void:
	if current_command_index >= command_blocks.size():
		_finish_execution()
		return
	var cmd : CommandBlock = command_blocks[current_command_index]
	_highlight(cmd)
	cmd.execute(robot)
	current_command_index += 1

func _on_action_completed() -> void:
	if not is_executing: return
	total_actions_taken += 1
	block_manager.on_action_taken(total_actions_taken)
	await get_tree().create_timer(0.15).timeout
	_execute_next()

func _finish_execution() -> void:
	is_executing        = false
	run_button.disabled = false
	_clear_highlights()

func _on_level_complete() -> void:
	is_executing        = false
	run_button.disabled = true
	_clear_highlights()
	await get_tree().create_timer(1.0).timeout
	current_level_index += 1
	_load_level(current_level_index)

func _show_win_screen() -> void:
	print("ALL LEVELS COMPLETE!")

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
