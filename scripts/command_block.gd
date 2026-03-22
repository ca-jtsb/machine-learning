extends Button
class_name CommandBlock

enum CommandType {
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	ATTACK,
	LOOP,
	APPEND,
	REPEAT_IF_ELSE,
}

# ── Basic block data ───────────────────────────────────────────────────────────
var command_type  : CommandType = CommandType.MOVE_UP
var loop_action   : CommandType = CommandType.MOVE_UP
var first_action  : CommandType = CommandType.MOVE_UP
var second_action : CommandType = CommandType.MOVE_RIGHT

# ── REPEAT_IF_ELSE data ────────────────────────────────────────────────────────
var repeat_count    : int    = 6
var check_direction : String = "LEFT"
var check_condition : String = "is_free"
var then_action     : CommandType = CommandType.MOVE_LEFT
var else_action     : CommandType = CommandType.MOVE_UP

# ── Compound condition (&&) ────────────────────────────────────────────────────
# When use_compound_condition = true, the IF check becomes:
#   (check_direction == check_condition) && (check_direction2 == check_condition2)
var use_compound_condition  : bool   = false
var check_direction2        : String = "UP"
var check_condition2        : String = "is_free"

# ── Compound then-action (&&) ─────────────────────────────────────────────────
# When use_compound_then = true, then_action AND then_action2 both execute
var use_compound_then  : bool        = false
var then_action2       : CommandType = CommandType.ATTACK

# When use_compound_else = true, else_action AND else_action2 both execute
var use_compound_else  : bool        = false
var else_action2       : CommandType = CommandType.ATTACK

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
		var condition_met : bool = _evaluate_condition(robot)

		if condition_met:
			await _run_one_step(robot, then_action)
			if use_compound_then:
				await _run_one_step(robot, then_action2)
		else:
			await _run_one_step(robot, else_action)
			if use_compound_else:
				await _run_one_step(robot, else_action2)

		await robot.get_tree().create_timer(0.12).timeout

		if robot.get_meta("level_done", false):
			break

func _evaluate_condition(robot: Robot) -> bool:
	# Primary condition
	var dir1_offset := _dir_string_to_offset(check_direction)
	var sense1_cell := robot.grid_position + dir1_offset
	var sense1       := robot.sense_cell(sense1_cell)  # true = free
	var cond1 : bool
	match check_condition:
		"is_free":        cond1 = sense1
		"is_obstacle":    cond1 = not sense1
		_:                cond1 = sense1

	if not use_compound_condition:
		return cond1

	# Compound: both conditions must be true (&&)
	var dir2_offset := _dir_string_to_offset(check_direction2)
	var sense2_cell := robot.grid_position + dir2_offset
	var sense2       := robot.sense_cell(sense2_cell)
	var cond2 : bool
	match check_condition2:
		"is_free":        cond2 = sense2
		"is_obstacle":    cond2 = not sense2
		_:                cond2 = sense2

	return cond1 and cond2

func _run_one_step(robot: Robot, t: CommandType) -> void:
	match t:
		CommandType.MOVE_UP:    await robot.move_one_up()
		CommandType.MOVE_DOWN:  await robot.move_one_down()
		CommandType.MOVE_LEFT:  await robot.move_one_left()
		CommandType.MOVE_RIGHT: await robot.move_one_right()
		CommandType.ATTACK:     await robot.attack_silent()

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
