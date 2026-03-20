extends Button
class_name CommandBlock

enum CommandType {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	ATTACK,
	LOOP,           # runs loop_action x3, counts as 1 turn
	APPEND,         # runs first_action then second_action, counts as 1 turn
	REPEAT_IF_ELSE, # new: repeat N times with per-cell if/else logic
}

# ── Basic block data ───────────────────────────────────────────────────────────
var command_type  : CommandType = CommandType.MOVE_UP
var loop_action   : CommandType = CommandType.MOVE_UP
var first_action  : CommandType = CommandType.MOVE_UP
var second_action : CommandType = CommandType.MOVE_RIGHT

# ── REPEAT_IF_ELSE block data (set by RepeatIfElseBlock widget) ────────────────
# repeat_count    : how many iterations
# check_direction : "UP" / "DOWN" / "LEFT" / "RIGHT"  — direction to sense
# check_condition : "is_free" / "is_obstacle"
# then_action     : CommandType (MOVE_*)  — action when condition is true
# else_action     : CommandType (MOVE_*)  — action when condition is false
var repeat_count    : int         = 6
var check_direction : String      = "LEFT"
var check_condition : String      = "is_free"
var then_action     : CommandType = CommandType.MOVE_LEFT
var else_action     : CommandType = CommandType.MOVE_UP

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
		CommandType.REPEAT_IF_ELSE:
			# This type is rendered by the RepeatIfElseBlock widget, not as a Button.
			# The CommandBlock itself is just a data carrier here.
			text = "[IF-ELSE]"
			add_theme_color_override("font_color", Color(1.0, 0.6, 0.1))

func _symbol(t: CommandType) -> String:
	match t:
		CommandType.MOVE_UP:    return "↑"
		CommandType.MOVE_DOWN:  return "↓"
		CommandType.MOVE_LEFT:  return "←"
		CommandType.MOVE_RIGHT: return "→"
		CommandType.ATTACK:     return "⚔"
	return "?"

# ── Execution ──────────────────────────────────────────────────────────────────
func execute(robot: Robot) -> void:
	match command_type:
		CommandType.MOVE_UP:    await robot.move_up()
		CommandType.MOVE_DOWN:  await robot.move_down()
		CommandType.MOVE_LEFT:  await robot.move_left()
		CommandType.MOVE_RIGHT: await robot.move_right()
		CommandType.ATTACK:     await robot.attack()

		CommandType.LOOP:
			for _i in 3:
				await _run_silent(robot, loop_action)
			robot.action_completed.emit()

		CommandType.APPEND:
			await _run_silent(robot, first_action)
			await _run_silent(robot, second_action)
			robot.action_completed.emit()

		CommandType.REPEAT_IF_ELSE:
			await _execute_repeat_if_else(robot)
			robot.action_completed.emit()

# ── REPEAT-IF-ELSE execution ───────────────────────────────────────────────────
func _execute_repeat_if_else(robot: Robot) -> void:
	for _i in repeat_count:
		# Sense the cell in check_direction
		var dir_offset : Vector2i = _dir_string_to_offset(check_direction)
		var sense_cell : Vector2i = robot.grid_position + dir_offset
		var sense_result : bool   = robot.sense_cell(sense_cell)  # true = free, false = blocked

		var condition_met : bool
		match check_condition:
			"is_free":     condition_met = sense_result
			"is_obstacle": condition_met = not sense_result
			_:             condition_met = sense_result

		var act : CommandType = then_action if condition_met else else_action
		await _run_one_step(robot, act)

		# Small delay between steps so movement is visible
		await robot.get_tree().create_timer(0.12).timeout

		# Stop early if level is complete (robot hit portal)
		if robot.get_meta("level_done", false):
			break

func _run_one_step(robot: Robot, t: CommandType) -> void:
	# Per-cell movement: moves exactly ONE tile (not slide-until-wall)
	match t:
		CommandType.MOVE_UP:    await robot.move_one_up()
		CommandType.MOVE_DOWN:  await robot.move_one_down()
		CommandType.MOVE_LEFT:  await robot.move_one_left()
		CommandType.MOVE_RIGHT: await robot.move_one_right()

func _dir_string_to_offset(dir: String) -> Vector2i:
	match dir:
		"UP":    return Vector2i( 0, -1)
		"DOWN":  return Vector2i( 0,  1)
		"LEFT":  return Vector2i(-1,  0)
		"RIGHT": return Vector2i( 1,  0)
	return Vector2i.ZERO

func _run_silent(robot: Robot, t: CommandType) -> void:
	match t:
		CommandType.MOVE_UP:    await robot.move_up_silent()
		CommandType.MOVE_DOWN:  await robot.move_down_silent()
		CommandType.MOVE_LEFT:  await robot.move_left_silent()
		CommandType.MOVE_RIGHT: await robot.move_right_silent()
		CommandType.ATTACK:     await robot.attack_silent()
