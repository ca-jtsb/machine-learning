extends Button
class_name CommandBlock

enum CommandType {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT
}

var command_type: CommandType = CommandType.MOVE_UP

func _init(cmd_type: CommandType = CommandType.MOVE_UP) -> void:
	command_type = cmd_type
	custom_minimum_size = Vector2(100, 40)

func _ready() -> void:
	# Set button text based on command
	match command_type:
		CommandType.MOVE_UP:
			text = "↑"
		CommandType.MOVE_DOWN:
			text = "↓"
		CommandType.MOVE_LEFT:
			text = "←"
		CommandType.MOVE_RIGHT:
			text = "→"
	
	# Styling
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_font_size_override("font_size", 24)

func execute(robot: Robot) -> void:
	match command_type:
		CommandType.MOVE_UP:
			robot.move_up()
		CommandType.MOVE_DOWN:
			robot.move_down()
		CommandType.MOVE_LEFT:
			robot.move_left()
		CommandType.MOVE_RIGHT:
			robot.move_right()
