extends Node2D

@onready var robot         : Robot          = $GameWorld/Robot
@onready var workspace     : HBoxContainer  = $UI/WorkspacePanel/Workspace
@onready var run_button    : Button         = $UI/RunButton
@onready var count_label   : Label          = $UI/ActionCounterPanel/VBoxContainer/CountLabel

# Command palette buttons
@onready var btn_up    : Button = $UI/CommandPalette/UpButton
@onready var btn_down  : Button = $UI/CommandPalette/DownButton
@onready var btn_left  : Button = $UI/CommandPalette/LeftButton
@onready var btn_right : Button = $UI/CommandPalette/RightButton

const MAX_ACTIONS : int = 8

var command_blocks        : Array[CommandBlock] = []
var is_executing          : bool = false
var current_command_index : int  = 0

func _ready() -> void:
	btn_up.pressed.connect(func():    _add_command(CommandBlock.CommandType.MOVE_UP))
	btn_down.pressed.connect(func():  _add_command(CommandBlock.CommandType.MOVE_DOWN))
	btn_left.pressed.connect(func():  _add_command(CommandBlock.CommandType.MOVE_LEFT))
	btn_right.pressed.connect(func(): _add_command(CommandBlock.CommandType.MOVE_RIGHT))

	run_button.pressed.connect(_on_run_pressed)
	robot.action_completed.connect(_on_robot_action_completed)

	_update_action_counter()

# ── Adding / removing commands ────────────────────────────────────────────────
func _add_command(cmd_type: CommandBlock.CommandType) -> void:
	if command_blocks.size() >= MAX_ACTIONS:
		_flash_error()
		return

	var block := CommandBlock.new(cmd_type)
	workspace.add_child(block)
	command_blocks.append(block)

	# Right-click to remove
	block.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_remove_command(block)
	)

	_update_action_counter()

func _remove_command(block: CommandBlock) -> void:
	command_blocks.erase(block)
	workspace.remove_child(block)
	block.queue_free()
	_update_action_counter()

# ── Run ───────────────────────────────────────────────────────────────────────
func _on_run_pressed() -> void:
	if is_executing or command_blocks.is_empty():
		return

	is_executing          = true
	current_command_index = 0
	run_button.disabled   = true
	_execute_next_command()

func _execute_next_command() -> void:
	if current_command_index >= command_blocks.size():
		_finish_execution()
		return

	var cmd : CommandBlock = command_blocks[current_command_index]
	_highlight_command(cmd)
	cmd.execute(robot)
	current_command_index += 1

func _on_robot_action_completed() -> void:
	if not is_executing:
		return
	await get_tree().create_timer(0.15).timeout
	_execute_next_command()

func _finish_execution() -> void:
	is_executing        = false
	run_button.disabled = false
	_clear_highlights()

# ── UI helpers ─────────────────────────────────────────────────────────────────
func _highlight_command(cmd: CommandBlock) -> void:
	_clear_highlights()
	cmd.modulate = Color.YELLOW

func _clear_highlights() -> void:
	for cmd in command_blocks:
		cmd.modulate = Color.WHITE

func _update_action_counter() -> void:
	var n : int = command_blocks.size()
	count_label.text = "%d / %d" % [n, MAX_ACTIONS]
	if n >= MAX_ACTIONS:
		count_label.add_theme_color_override("font_color", Color.YELLOW)
	else:
		count_label.add_theme_color_override("font_color", Color.GREEN)

func _flash_error() -> void:
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	_update_action_counter()
