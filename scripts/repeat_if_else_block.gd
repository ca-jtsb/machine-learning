extends PanelContainer
class_name RepeatIfElseBlock

signal changed

# ── Slot data — set BEFORE adding to scene tree ───────────────────────────────
var repeat_count    : int     = 6      # initial value shown in spinbox
var repeat_fixed    : bool    = false  # if true, spinbox is read-only
var check_direction : Variant = null   # null = dropdown | "UP"/"DOWN"/"LEFT"/"RIGHT"
var check_condition : Variant = null   # null = dropdown | "is_free"/"is_obstacle"
var then_action     : Variant = null   # null = dropdown | "move_up" etc
var else_action     : Variant = null   # null = dropdown | "move_up" etc

const MAX_REPEAT    : int = 50   # cap to prevent runaway loops
const MIN_REPEAT    : int = 1

var _repeat_spin : SpinBox    = null
var _dir_opt     : OptionButton = null
var _cond_opt    : OptionButton = null
var _then_opt    : OptionButton = null
var _else_opt    : OptionButton = null

const DIR_OPTIONS  : Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
const COND_OPTIONS : Array[String] = ["is_free", "is_obstacle"]
const ACT_OPTIONS  : Array[String] = ["move_up", "move_down", "move_left", "move_right", "attack"]
const ACT_LABELS   : Array[String] = ["↑ MOVE UP", "↓ MOVE DOWN", "← MOVE LEFT", "→ MOVE RIGHT", "⚔ ATTACK"]

const COLOR_OUTER : Color = Color(0.95, 0.55, 0.05, 1.0)
const COLOR_INNER : Color = Color(0.80, 0.42, 0.02, 1.0)
const COLOR_TEXT  : Color = Color(1.0,  1.0,  1.0,  1.0)

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = COLOR_OUTER
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		outer_style.set("corner_radius_" + corner, 8)
	add_theme_stylebox_override("panel", outer_style)
	custom_minimum_size = Vector2(320, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var outer_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, 10 if side in ["left","right"] else 8)
	add_child(outer_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	outer_margin.add_child(vbox)

	# ── REPEAT header row ─────────────────────────────────────────────────────
	var repeat_row := HBoxContainer.new()
	repeat_row.add_theme_constant_override("separation", 6)
	vbox.add_child(repeat_row)

	var repeat_icon := Label.new()
	repeat_icon.text = "↺  REPEAT"
	repeat_icon.add_theme_color_override("font_color", COLOR_TEXT)
	repeat_icon.add_theme_font_size_override("font_size", 15)
	repeat_row.add_child(repeat_icon)

	# SpinBox for repeat count
	_repeat_spin = SpinBox.new()
	_repeat_spin.min_value = MIN_REPEAT
	_repeat_spin.max_value = MAX_REPEAT
	_repeat_spin.step      = 1
	_repeat_spin.value     = clamp(repeat_count, MIN_REPEAT, MAX_REPEAT)
	_repeat_spin.custom_minimum_size = Vector2(80, 0)
	_repeat_spin.editable  = not repeat_fixed
	_repeat_spin.suffix    = "×"
	_repeat_spin.value_changed.connect(func(_v): changed.emit())
	# Validate raw text input — reject non-numbers and clamp
	_repeat_spin.get_line_edit().text_submitted.connect(_on_repeat_text_submitted)
	_repeat_spin.get_line_edit().focus_exited.connect(_on_repeat_focus_exited)
	repeat_row.add_child(_repeat_spin)

	# ── Inner panel ───────────────────────────────────────────────────────────
	var inner_panel := PanelContainer.new()
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = COLOR_INNER
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		inner_style.set("corner_radius_" + corner, 5)
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	vbox.add_child(inner_panel)

	var inner_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		inner_margin.add_theme_constant_override("margin_" + side, 8 if side in ["left","right"] else 6)
	inner_panel.add_child(inner_margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	inner_margin.add_child(inner_vbox)

	# IF row
	var if_row := HBoxContainer.new()
	if_row.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(if_row)

	var if_lbl := Label.new()
	if_lbl.text = "if  dir:"
	if_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	if_lbl.add_theme_font_size_override("font_size", 13)
	if_row.add_child(if_lbl)

	if check_direction == null:
		_dir_opt = _make_dropdown(DIR_OPTIONS)
		if_row.add_child(_dir_opt)
		_dir_opt.item_selected.connect(func(_i): changed.emit())
	else:
		if_row.add_child(_make_fixed_label(str(check_direction)))

	var eq_lbl := Label.new()
	eq_lbl.text = "  =="
	eq_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	eq_lbl.add_theme_font_size_override("font_size", 13)
	if_row.add_child(eq_lbl)

	if check_condition == null:
		_cond_opt = _make_dropdown(COND_OPTIONS)
		if_row.add_child(_cond_opt)
		_cond_opt.item_selected.connect(func(_i): changed.emit())
	else:
		if_row.add_child(_make_fixed_label(str(check_condition)))

	# THEN row
	var then_row := HBoxContainer.new()
	then_row.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(then_row)

	var then_lbl := Label.new()
	then_lbl.text = "  then:"
	then_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	then_lbl.add_theme_font_size_override("font_size", 13)
	then_row.add_child(then_lbl)

	if then_action == null:
		_then_opt = _make_dropdown(ACT_LABELS)
		then_row.add_child(_then_opt)
		_then_opt.item_selected.connect(func(_i): changed.emit())
	else:
		then_row.add_child(_make_fixed_label(_action_to_label(str(then_action))))

	# ELSE row
	var else_row := HBoxContainer.new()
	else_row.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(else_row)

	var else_lbl := Label.new()
	else_lbl.text = "  else:"
	else_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	else_lbl.add_theme_font_size_override("font_size", 13)
	else_row.add_child(else_lbl)

	if else_action == null:
		_else_opt = _make_dropdown(ACT_LABELS)
		else_row.add_child(_else_opt)
		_else_opt.item_selected.connect(func(_i): changed.emit())
	else:
		else_row.add_child(_make_fixed_label(_action_to_label(str(else_action))))

# ── SpinBox validation ─────────────────────────────────────────────────────────
func _on_repeat_text_submitted(text: String) -> void:
	_validate_and_apply(text)

func _on_repeat_focus_exited() -> void:
	_validate_and_apply(_repeat_spin.get_line_edit().text)

func _validate_and_apply(text: String) -> void:
	var trimmed := text.strip_edges()
	if not trimmed.is_valid_int():
		# Not a number — revert to current spinbox value
		_repeat_spin.get_line_edit().text = str(int(_repeat_spin.value))
		return
	var val := int(trimmed)
	if val < MIN_REPEAT:
		val = MIN_REPEAT
	elif val > MAX_REPEAT:
		val = MAX_REPEAT
	_repeat_spin.set_value_no_signal(float(val))
	_repeat_spin.get_line_edit().text = str(val)
	changed.emit()

# ── Helpers ────────────────────────────────────────────────────────────────────
func _make_dropdown(options: Array[String]) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(120, 28)
	ob.add_theme_font_size_override("font_size", 12)
	for opt in options:
		ob.add_item(opt)
	return ob

func _make_fixed_label(txt: String) -> Label:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.5))
	lbl.add_theme_font_size_override("font_size", 13)
	return lbl

func _action_to_label(act: String) -> String:
	match act:
		"move_up":    return "↑ MOVE UP"
		"move_down":  return "↓ MOVE DOWN"
		"move_left":  return "← MOVE LEFT"
		"move_right": return "→ MOVE RIGHT"
		"attack":     return "⚔ ATTACK"
	return act

# ── Read values ────────────────────────────────────────────────────────────────
func get_repeat_count() -> int:
	if _repeat_spin:
		return int(_repeat_spin.value)
	return repeat_count

func get_check_direction() -> String:
	if check_direction != null: return str(check_direction)
	if _dir_opt: return DIR_OPTIONS[_dir_opt.selected]
	return "LEFT"

func get_check_condition() -> String:
	if check_condition != null: return str(check_condition)
	if _cond_opt: return COND_OPTIONS[_cond_opt.selected]
	return "is_free"

func get_then_action() -> CommandBlock.CommandType:
	if then_action != null: return _str_to_cmd(str(then_action))
	if _then_opt: return _str_to_cmd(ACT_OPTIONS[_then_opt.selected])
	return CommandBlock.CommandType.MOVE_UP

func get_else_action() -> CommandBlock.CommandType:
	if else_action != null: return _str_to_cmd(str(else_action))
	if _else_opt: return _str_to_cmd(ACT_OPTIONS[_else_opt.selected])
	return CommandBlock.CommandType.MOVE_UP

func _str_to_cmd(s: String) -> CommandBlock.CommandType:
	match s:
		"move_up":    return CommandBlock.CommandType.MOVE_UP
		"move_down":  return CommandBlock.CommandType.MOVE_DOWN
		"move_left":  return CommandBlock.CommandType.MOVE_LEFT
		"move_right": return CommandBlock.CommandType.MOVE_RIGHT
		"attack":     return CommandBlock.CommandType.ATTACK
	return CommandBlock.CommandType.MOVE_UP

func build_command_block() -> CommandBlock:
	var cb := CommandBlock.new(CommandBlock.CommandType.REPEAT_IF_ELSE)
	cb.repeat_count    = get_repeat_count()
	cb.check_direction = get_check_direction()
	cb.check_condition = get_check_condition()
	cb.then_action     = get_then_action()
	cb.else_action     = get_else_action()
	return cb
