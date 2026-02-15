extends Node2D

@onready var robot: Robot = $GameWorld/Robot
@onready var workspace: HBoxContainer = $UI/WorkspacePanel/Workspace
@onready var run_button: Button = $UI/RunButton

# Command palette buttons
@onready var btn_up: Button = $UI/CommandPalette/UpButton
@onready var btn_down: Button = $UI/CommandPalette/DownButton
@onready var btn_left: Button = $UI/CommandPalette/LeftButton
@onready var btn_right: Button = $UI/CommandPalette/RightButton

var command_blocks: Array[CommandBlock] = []
var is_executing: bool = false
var current_command_index: int = 0

func _ready() -> void:
	print("Main scene ready!")
	
	# Connect palette buttons
	btn_up.pressed.connect(func(): _add_command(CommandBlock.CommandType.MOVE_UP))
	btn_down.pressed.connect(func(): _add_command(CommandBlock.CommandType.MOVE_DOWN))
	btn_left.pressed.connect(func(): _add_command(CommandBlock.CommandType.MOVE_LEFT))
	btn_right.pressed.connect(func(): _add_command(CommandBlock.CommandType.MOVE_RIGHT))
	
	# Connect run button
	run_button.pressed.connect(_on_run_pressed)
	
	# Connect robot signals
	robot.action_completed.connect(_on_robot_action_completed)

func _add_command(cmd_type: CommandBlock.CommandType) -> void:
	print("Adding command: ", CommandBlock.CommandType.keys()[cmd_type])
	
	# Create new command block
	var cmd_block = CommandBlock.new(cmd_type)
	workspace.add_child(cmd_block)
	command_blocks.append(cmd_block)
	
	# Allow removing by right-click
	cmd_block.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
				_remove_command(cmd_block)
	)

func _remove_command(cmd_block: CommandBlock) -> void:
	command_blocks.erase(cmd_block)
	workspace.remove_child(cmd_block)
	cmd_block.queue_free()
	print("Command removed")

func _on_run_pressed() -> void:
	if is_executing:
		print("Already executing!")
		return
	
	if command_blocks.is_empty():
		print("No commands to execute!")
		return
	
	print("Starting execution...")
	is_executing = true
	current_command_index = 0
	run_button.disabled = true
	_execute_next_command()

func _execute_next_command() -> void:
	if current_command_index >= command_blocks.size():
		_finish_execution()
		return
	
	var cmd = command_blocks[current_command_index]
	print("Executing command ", current_command_index, ": ", cmd.text)
	
	# Highlight current command
	_highlight_command(cmd)
	
	# Execute on robot
	cmd.execute(robot)
	
	current_command_index += 1

func _on_robot_action_completed() -> void:
	if is_executing:
		# Wait a bit before next command
		await get_tree().create_timer(0.2).timeout
		_execute_next_command()

func _finish_execution() -> void:
	print("Execution complete!")
	is_executing = false
	run_button.disabled = false
	_clear_highlights()

func _highlight_command(cmd: CommandBlock) -> void:
	_clear_highlights()
	cmd.modulate = Color.YELLOW

func _clear_highlights() -> void:
	for cmd in command_blocks:
		cmd.modulate = Color.WHITE
