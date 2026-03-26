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

# ══════════════════════════════════════════════════════════════════════════════
# COMMAND BLOCK ASSETS
# ══════════════════════════════════════════════════════════════════════════════
const CMD_ASSETS : Dictionary = {
	CommandType.MOVE_UP:    { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
	CommandType.MOVE_DOWN:  { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
	CommandType.MOVE_LEFT:  { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
	CommandType.MOVE_RIGHT: { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
	CommandType.ATTACK:     { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
	CommandType.LOOP:       { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
	CommandType.APPEND:     { "texture_path": "", "icon_size": Vector2(32, 32), "icon_align": "left" },
}

# ── Colors ─────────────────────────────────────────────────────────────────────
const COLOR_NORMAL  : Color = Color(0.95, 0.55, 0.05, 0.85)   # Orange (semi-transparent)
const COLOR_HIGHLIGHT : Color = Color(1.0, 0.85, 0.0, 1.0)    # Bright yellow-gold
const COLOR_TEXT_NORMAL : Color = Color.WHITE
const COLOR_TEXT_HIGHLIGHT : Color = Color(0.15, 0.15, 0.15, 1.0)  # Dark text on bright bg

# ── Basic block data ───────────────────────────────────────────────────────────
var command_type  : CommandType = CommandType.MOVE_UP
var loop_action   : CommandType = CommandType.MOVE_UP
var loop_count    : int = 3 
var first_action  : CommandType = CommandType.MOVE_UP
var second_action : CommandType = CommandType.MOVE_RIGHT

# ── REPEAT_IF_ELSE data ────────────────────────────────────────────────────────
var repeat_count    : int    = 6
var check_direction : String = "LEFT"
var check_condition : String = "is_free"
var then_action     : CommandType = CommandType.MOVE_LEFT
var else_action     : CommandType = CommandType.MOVE_UP

# ── Compound condition (&&) ────────────────────────────────────────────────────
var use_compound_condition  : bool   = false
var check_direction2        : String = "UP"
var check_condition2        : String = "is_free"

# ── Compound then-action (&&) ─────────────────────────────────────────────────
var use_compound_then  : bool        = false
var then_action2       : CommandType = CommandType.ATTACK

# ── Compound else-action (&&) ─────────────────────────────────────────────────
var use_compound_else  : bool        = false
var else_action2       : CommandType = CommandType.ATTACK

# ── Directional attack overrides (for REPEAT-IF-ELSE) ─────────────────────────
var then_attack_dir   : String = ""
var then2_attack_dir  : String = ""
var else_attack_dir   : String = ""
var else2_attack_dir  : String = ""

# ── Internal state ─────────────────────────────────────────────────────────────
var _base_style : StyleBoxFlat = null
var _is_highlighted : bool = false

func _init(cmd_type: CommandType = CommandType.MOVE_UP) -> void:
	command_type          = cmd_type
	custom_minimum_size   = Vector2(0, 44)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _ready() -> void:
	_update_label()
	GameConfig.apply(self, GameConfig.FONT_SIZE_NORMAL)

func _update_label() -> void:
	_base_style = StyleBoxFlat.new()
	_base_style.bg_color = COLOR_NORMAL
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		_base_style.set("corner_radius_" + corner, 5)
	
	# Add subtle border for definition
	_base_style.border_width_left = 2
	_base_style.border_width_right = 2
	_base_style.border_width_top = 2
	_base_style.border_width_bottom = 2
	_base_style.border_color = Color(0.5, 0.25, 0.0, 1.0)
	
	add_theme_stylebox_override("normal",  _base_style.duplicate())
	add_theme_stylebox_override("hover",   _base_style.duplicate())
	add_theme_stylebox_override("pressed", _base_style.duplicate())
	add_theme_stylebox_override("focus",   _base_style.duplicate())
	add_theme_color_override("font_color", COLOR_TEXT_NORMAL)

	match command_type:
		CommandType.MOVE_UP:        text = "↑  Move Up"
		CommandType.MOVE_DOWN:      text = "↓  Move Down"
		CommandType.MOVE_LEFT:      text = "←  Move Left"
		CommandType.MOVE_RIGHT:     text = "→  Move Right"
		CommandType.ATTACK:         text = "⚔  Attack"
		CommandType.LOOP:           text = "↺  Loop  %s  ×%d" % [_symbol(loop_action), loop_count]
		CommandType.APPEND:         text = "%s  &&  %s" % [_symbol(first_action), _symbol(second_action)]
		CommandType.REPEAT_IF_ELSE: text = "↺  If-Else"

	var old_icon = get_node_or_null("CmdIcon")
	if old_icon:
		old_icon.queue_free()

	var cfg : Dictionary = CMD_ASSETS.get(command_type, {})
	var tex_path : String = cfg.get("texture_path", "")
	if tex_path == "" or not ResourceLoader.exists(tex_path):
		return

	var icon_size  : Vector2 = cfg.get("icon_size",  Vector2(32, 32))
	var icon_align : String  = cfg.get("icon_align", "left")

	add_theme_color_override("font_color", Color(0, 0, 0, 0))

	var tex_rect := TextureRect.new()
	tex_rect.name                = "CmdIcon"
	tex_rect.texture             = load(tex_path)
	tex_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = icon_size
	tex_rect.size                = icon_size
	tex_rect.mouse_filter        = Control.MOUSE_FILTER_IGNORE

	match icon_align:
		"left":
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
			tex_rect.offset_top    = -icon_size.y * 0.5
			tex_rect.offset_bottom =  icon_size.y * 0.5
			tex_rect.offset_left   = 8.0
			tex_rect.offset_right  = 8.0 + icon_size.x
		"center":
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
			tex_rect.offset_left   = -icon_size.x * 0.5
			tex_rect.offset_right  =  icon_size.x * 0.5
			tex_rect.offset_top    = -icon_size.y * 0.5
			tex_rect.offset_bottom =  icon_size.y * 0.5
		"right":
			tex_rect.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			tex_rect.offset_top    = -icon_size.y * 0.5
			tex_rect.offset_bottom =  icon_size.y * 0.5
			tex_rect.offset_left   = -(8.0 + icon_size.x)
			tex_rect.offset_right  = -8.0

	add_child(tex_rect)

# ══════════════════════════════════════════════════════════════════════════════
# ⭐ NEW: Highlight function - call this when executing this block
# ══════════════════════════════════════════════════════════════════════════════
func set_highlighted(is_active: bool) -> void:
	_is_highlighted = is_active
	
	var highlight_style := _base_style.duplicate() if _base_style else StyleBoxFlat.new()
	
	if is_active:
		# Bright yellow-gold background
		highlight_style.bg_color = COLOR_HIGHLIGHT
		# Thicker, brighter border for glow effect
		highlight_style.border_width_left = 3
		highlight_style.border_width_right = 3
		highlight_style.border_width_top = 3
		highlight_style.border_width_bottom = 3
		highlight_style.border_color = Color(1.0, 0.9, 0.3, 1.0)
		# Dark text for contrast on bright background
		add_theme_color_override("font_color", COLOR_TEXT_HIGHLIGHT)
		# Make icon visible if it exists
		var icon = get_node_or_null("CmdIcon")
		if icon:
			icon.modulate = Color(0.2, 0.2, 0.2, 1.0)  # Darken icon
	else:
		# Restore normal orange
		highlight_style.bg_color = COLOR_NORMAL
		highlight_style.border_width_left = 2
		highlight_style.border_width_right = 2
		highlight_style.border_width_top = 2
		highlight_style.border_width_bottom = 2
		highlight_style.border_color = Color(0.5, 0.25, 0.0, 1.0)
		# White text
		add_theme_color_override("font_color", COLOR_TEXT_NORMAL)
		# Restore icon
		var icon = get_node_or_null("CmdIcon")
		if icon:
			icon.modulate = Color.WHITE
	
	add_theme_stylebox_override("normal",  highlight_style)
	add_theme_stylebox_override("hover",   highlight_style)
	add_theme_stylebox_override("pressed", highlight_style)
	add_theme_stylebox_override("focus",   highlight_style)

func _symbol(t: CommandType) -> String:
	match t:
		CommandType.MOVE_UP:    return "↑"
		CommandType.MOVE_DOWN:  return "↓"
		CommandType.MOVE_LEFT:  return "←"
		CommandType.MOVE_RIGHT: return "→"
		CommandType.ATTACK:     return "⚔"
	return "?"

# ── Execution ─────────────────────────────────────────────────────────────────
func execute(robot: Robot) -> void:
	match command_type:
		CommandType.MOVE_UP:    await robot.move_up()
		CommandType.MOVE_DOWN:  await robot.move_down()
		CommandType.MOVE_LEFT:  await robot.move_left()
		CommandType.MOVE_RIGHT: await robot.move_right()
		CommandType.ATTACK:     await robot.attack()
		CommandType.LOOP:
			for _i in loop_count:
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
			await _run_one_step(robot, then_action, then_attack_dir)
			if robot.get_meta("hit_wall_abort", false): break
			if use_compound_then:
				await _run_one_step(robot, then_action2, then2_attack_dir)
				if robot.get_meta("hit_wall_abort", false): break
		else:
			await _run_one_step(robot, else_action, else_attack_dir)
			if robot.get_meta("hit_wall_abort", false): break
			if use_compound_else:
				await _run_one_step(robot, else_action2, else2_attack_dir)
				if robot.get_meta("hit_wall_abort", false): break

		await robot.get_tree().create_timer(0.12).timeout

		if robot.get_meta("level_done", false):
			break
		if robot.get_meta("hit_wall_abort", false):
			break

func _evaluate_condition(robot: Robot) -> bool:
	var dir1_offset := _dir_string_to_offset(check_direction)
	var sense1_cell := robot.grid_position + dir1_offset
	var sense1       := robot.sense_cell(sense1_cell)
	var cond1 : bool
	match check_condition:
		"is_free":     cond1 = sense1
		"is_obstacle": cond1 = not sense1
		_:             cond1 = sense1

	if not use_compound_condition:
		return cond1

	var dir2_offset := _dir_string_to_offset(check_direction2)
	var sense2_cell := robot.grid_position + dir2_offset
	var sense2       := robot.sense_cell(sense2_cell)
	var cond2 : bool
	match check_condition2:
		"is_free":     cond2 = sense2
		"is_obstacle": cond2 = not sense2
		_:             cond2 = sense2

	return cond1 and cond2

func _run_one_step(robot: Robot, t: CommandType, atk_dir: String = "") -> void:
	match t:
		CommandType.MOVE_UP:    await robot.move_one_up()
		CommandType.MOVE_DOWN:  await robot.move_one_down()
		CommandType.MOVE_LEFT:  await robot.move_one_left()
		CommandType.MOVE_RIGHT: await robot.move_one_right()
		CommandType.ATTACK:
			if atk_dir != "":
				await robot.attack_silent_dir(_str_to_direction(atk_dir))
			else:
				await robot.attack_silent()

func _str_to_direction(dir: String) -> Robot.Direction:
	match dir:
		"UP":    return Robot.Direction.UP
		"DOWN":  return Robot.Direction.DOWN
		"LEFT":  return Robot.Direction.LEFT
		"RIGHT": return Robot.Direction.RIGHT
	return Robot.Direction.RIGHT

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
