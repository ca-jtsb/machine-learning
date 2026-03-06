extends Button
class_name CommandBlock

enum CommandType {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	ATTACK
}

var command_type : CommandType = CommandType.MOVE_UP

func _init(cmd_type: CommandType = CommandType.MOVE_UP) -> void:
	command_type        = cmd_type
	custom_minimum_size = Vector2(80, 40)

func _ready() -> void:
	match command_type:
		CommandType.MOVE_UP:    text = "↑"
		CommandType.MOVE_DOWN:  text = "↓"
		CommandType.MOVE_LEFT:  text = "←"
		CommandType.MOVE_RIGHT: text = "→"
		CommandType.ATTACK:     text = "⚔"
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_font_size_override("font_size", 22)

# Node instead of Robot type — avoids dependency on class_name
func execute(robot: Node) -> void:
	match command_type:
		CommandType.MOVE_UP:    await robot.move_up()
		CommandType.MOVE_DOWN:  await robot.move_down()
		CommandType.MOVE_LEFT:  await robot.move_left()
		CommandType.MOVE_RIGHT: await robot.move_right()
		CommandType.ATTACK:     await robot.attack()
