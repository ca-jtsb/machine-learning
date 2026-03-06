extends Button
class_name CommandBlock

enum CommandType {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	ATTACK,
	LOOP,    # runs loop_action x3, counts as 1 turn
	APPEND   # runs first_action then second_action, counts as 1 turn
}

var command_type  : CommandType = CommandType.MOVE_UP
var loop_action   : CommandType = CommandType.MOVE_UP
var first_action  : CommandType = CommandType.MOVE_UP
var second_action : CommandType = CommandType.MOVE_RIGHT

func _init(cmd_type: CommandType = CommandType.MOVE_UP) -> void:
	command_type        = cmd_type
	custom_minimum_size = Vector2(100, 40)

func _ready() -> void:
	_update_label()
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_font_size_override("font_size", 16)

func _update_label() -> void:
	match command_type:
		CommandType.MOVE_UP:    text = "↑"
		CommandType.MOVE_DOWN:  text = "↓"
		CommandType.MOVE_LEFT:  text = "←"
		CommandType.MOVE_RIGHT: text = "→"
		CommandType.ATTACK:     text = "⚔"
		CommandType.LOOP:
			text = "↺ %s ×3" % _symbol(loop_action)
			add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		CommandType.APPEND:
			text = "%s && %s" % [_symbol(first_action), _symbol(second_action)]
			add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))

func _symbol(t: CommandType) -> String:
	match t:
		CommandType.MOVE_UP:    return "↑"
		CommandType.MOVE_DOWN:  return "↓"
		CommandType.MOVE_LEFT:  return "←"
		CommandType.MOVE_RIGHT: return "→"
		CommandType.ATTACK:     return "⚔"
	return "?"

# ── Execution ──────────────────────────────────────────────────────────────────
# Basic commands call the public robot methods which emit action_completed.
# LOOP and APPEND call the _silent versions so sub-actions don't fire the signal,
# then emit action_completed exactly once at the end.
func execute(robot: Robot) -> void:
	match command_type:
		CommandType.MOVE_UP:    await robot.move_up()
		CommandType.MOVE_DOWN:  await robot.move_down()
		CommandType.MOVE_LEFT:  await robot.move_left()
		CommandType.MOVE_RIGHT: await robot.move_right()
		CommandType.ATTACK:     await robot.attack()

		CommandType.LOOP:
			# Run the sub-action 3 times silently, then signal once
			for _i in 3:
				await _run_silent(robot, loop_action)
			robot.action_completed.emit()

		CommandType.APPEND:
			# Run both sub-actions silently, then signal once
			await _run_silent(robot, first_action)
			await _run_silent(robot, second_action)
			robot.action_completed.emit()

## Calls the silent (no-signal) version of each robot action.
func _run_silent(robot: Robot, t: CommandType) -> void:
	match t:
		CommandType.MOVE_UP:    await robot.move_up_silent()
		CommandType.MOVE_DOWN:  await robot.move_down_silent()
		CommandType.MOVE_LEFT:  await robot.move_left_silent()
		CommandType.MOVE_RIGHT: await robot.move_right_silent()
		CommandType.ATTACK:     await robot.attack_silent()
