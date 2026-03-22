extends PanelContainer
class_name RepeatIfElseBlock

signal changed

# ── Slot data — set BEFORE adding to scene tree ───────────────────────────────
var repeat_count    : int     = 6
var repeat_fixed    : bool    = false

# Primary condition
var check_direction : Variant = null   # null=dropdown | "UP"/"DOWN"/"LEFT"/"RIGHT"
var check_condition : Variant = null   # null=dropdown | "is_free"/"is_obstacle"

# Compound condition (&&) — set both to enable
var use_compound_condition : bool    = false
var check_direction2       : Variant = null
var check_condition2       : Variant = null

# Then action
var then_action  : Variant = null   # null=dropdown | "move_up" etc
# Compound then (&&)
var use_compound_then : bool    = false
var then_action2      : Variant = null

# Else action
var else_action  : Variant = null
# Compound else (&&)
var use_compound_else : bool    = false
var else_action2      : Variant = null

const MAX_REPEAT   : int = 50
const MIN_REPEAT   : int = 1

const DIR_OPTIONS  : Array[String] = ["UP", "DOWN", "LEFT", "RIGHT"]
const COND_OPTIONS : Array[String] = ["is_free", "is_obstacle"]
const ACT_OPTIONS  : Array[String] = ["move_up", "move_down", "move_left", "move_right", "attack"]
const ACT_LABELS   : Array[String] = ["↑ MOVE UP", "↓ MOVE DOWN", "← MOVE LEFT", "→ MOVE RIGHT", "⚔ ATTACK"]

const COLOR_OUTER : Color = Color(0.95, 0.55, 0.05, 1.0)
const COLOR_INNER : Color = Color(0.80, 0.42, 0.02, 1.0)
const COLOR_TEXT  : Color = Color(1.0,  1.0,  1.0,  1.0)

# Internal widget refs
var _repeat_spin  : SpinBox     = null
var _dir_opt      : OptionButton = null
var _cond_opt     : OptionButton = null
var _dir2_opt     : OptionButton = null
var _cond2_opt    : OptionButton = null
var _then_opt     : OptionButton = null
var _then2_opt    : OptionButton = null
var _else_opt     : OptionButton = null
var _else2_opt    : OptionButton = null

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

	# ── REPEAT header ─────────────────────────────────────────────────────────
	var repeat_row := HBoxContainer.new()
	repeat_row.add_theme_constant_override("separation", 6)
	vbox.add_child(repeat_row)

	var repeat_lbl := Label.new()
	repeat_lbl.text = "↺  REPEAT"
	repeat_lbl.add_theme_color_override("font_color", COLOR_TEXT)
	repeat_lbl.add_theme_font_size_override("font_size", 15)
	repeat_row.add_child(repeat_lbl)

	_repeat_spin = SpinBox.new()
	_repeat_spin.min_value = MIN_REPEAT
	_repeat_spin.max_value = MAX_REPEAT
	_repeat_spin.step      = 1
	_repeat_spin.value     = clamp(repeat_count, MIN_REPEAT, MAX_REPEAT)
	_repeat_spin.custom_minimum_size = Vector2(80, 0)
	_repeat_spin.editable  = not repeat_fixed
	_repeat_spin.suffix    = "×"
	_repeat_spin.value_changed.connect(func(_v): changed.emit())
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

	# ── IF condition row ──────────────────────────────────────────────────────
	var if_row := HBoxContainer.new()
	if_row.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(if_row)

	_add_label_to(if_row, "if  dir:", 13)

	if check_direction == null:
		_dir_opt = _make_dropdown(DIR_OPTIONS)
		if_row.add_child(_dir_opt)
		_dir_opt.item_selected.connect(func(_i): changed.emit())
	else:
		if_row.add_child(_make_fixed_label(str(check_direction)))

	_add_label_to(if_row, "  ==", 13, Color(1.0, 1.0, 0.5))

	if check_condition == null:
		_cond_opt = _make_dropdown(COND_OPTIONS)
		if_row.add_child(_cond_opt)
		_cond_opt.item_selected.connect(func(_i): changed.emit())
	else:
		if_row.add_child(_make_fixed_label(str(check_condition)))

	# ── Compound condition (&&) ───────────────────────────────────────────────
	if use_compound_condition:
		_add_label_to(if_row, "  &&", 13, Color(0.4, 0.9, 1.0))
		_add_label_to(if_row, " dir:", 13)

		if check_direction2 == null:
			_dir2_opt = _make_dropdown(DIR_OPTIONS)
			if_row.add_child(_dir2_opt)
			_dir2_opt.item_selected.connect(func(_i): changed.emit())
		else:
			if_row.add_child(_make_fixed_label(str(check_direction2)))

		_add_label_to(if_row, "  ==", 13, Color(1.0, 1.0, 0.5))

		if check_condition2 == null:
			_cond2_opt = _make_dropdown(COND_OPTIONS)
			if_row.add_child(_cond2_opt)
			_cond2_opt.item_selected.connect(func(_i): changed.emit())
		else:
			if_row.add_child(_make_fixed_label(str(check_condition2)))

	# ── THEN row ──────────────────────────────────────────────────────────────
	var then_row := HBoxContainer.new()
	then_row.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(then_row)
	_add_label_to(then_row, "  then:", 13)

	if then_action == null:
		_then_opt = _make_dropdown(ACT_LABELS)
		then_row.add_child(_then_opt)
		_then_opt.item_selected.connect(func(_i): changed.emit())
	else:
		then_row.add_child(_make_fixed_label(_action_to_label(str(then_action))))

	if use_compound_then:
		_add_label_to(then_row, "  &&", 13, Color(0.4, 0.9, 1.0))
		if then_action2 == null:
			_then2_opt = _make_dropdown(ACT_LABELS)
			then_row.add_child(_then2_opt)
			_then2_opt.item_selected.connect(func(_i): changed.emit())
		else:
			then_row.add_child(_make_fixed_label(_action_to_label(str(then_action2))))

	# ── ELSE row ──────────────────────────────────────────────────────────────
	var else_row := HBoxContainer.new()
	else_row.add_theme_constant_override("separation", 4)
	inner_vbox.add_child(else_row)
	_add_label_to(else_row, "  else:", 13)

	if else_action == null:
		_else_opt = _make_dropdown(ACT_LABELS)
		else_row.add_child(_else_opt)
		_else_opt.item_selected.connect(func(_i): changed.emit())
	else:
		else_row.add_child(_make_fixed_label(_action_to_label(str(else_action))))

	if use_compound_else:
		_add_label_to(else_row, "  &&", 13, Color(0.4, 0.9, 1.0))
		if else_action2 == null:
			_else2_opt = _make_dropdown(ACT_LABELS)
			else_row.add_child(_else2_opt)
			_else2_opt.item_selected.connect(func(_i): changed.emit())
		else:
			else_row.add_child(_make_fixed_label(_action_to_label(str(else_action2))))

# ── SpinBox validation ─────────────────────────────────────────────────────────
func _on_repeat_text_submitted(text: String) -> void: _validate_and_apply(text)
func _on_repeat_focus_exited() -> void: _validate_and_apply(_repeat_spin.get_line_edit().text)

func _validate_and_apply(text: String) -> void:
	var trimmed := text.strip_edges()
	if not trimmed.is_valid_int():
		_repeat_spin.get_line_edit().text = str(int(_repeat_spin.value)); return
	var val : int = clamp(int(trimmed), MIN_REPEAT, MAX_REPEAT)
	_repeat_spin.set_value_no_signal(float(val))
	_repeat_spin.get_line_edit().text = str(val)
	changed.emit()

# ── UI helpers ─────────────────────────────────────────────────────────────────
func _add_label_to(parent: Node, text: String, font_sz: int, color: Color = COLOR_TEXT) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", font_sz)
	parent.add_child(lbl)

func _make_dropdown(options: Array[String]) -> OptionButton:
	var ob := OptionButton.new()
	ob.custom_minimum_size = Vector2(120, 28)
	ob.add_theme_font_size_override("font_size", 12)
	for opt in options: ob.add_item(opt)
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
	return int(_repeat_spin.value) if _repeat_spin else repeat_count

func get_check_direction() -> String:
	if check_direction != null: return str(check_direction)
	if _dir_opt: return DIR_OPTIONS[_dir_opt.selected]
	return "LEFT"

func get_check_condition() -> String:
	if check_condition != null: return str(check_condition)
	if _cond_opt: return COND_OPTIONS[_cond_opt.selected]
	return "is_free"

func get_check_direction2() -> String:
	if check_direction2 != null: return str(check_direction2)
	if _dir2_opt: return DIR_OPTIONS[_dir2_opt.selected]
	return "UP"

func get_check_condition2() -> String:
	if check_condition2 != null: return str(check_condition2)
	if _cond2_opt: return COND_OPTIONS[_cond2_opt.selected]
	return "is_free"

func get_then_action() -> CommandBlock.CommandType:
	var s := str(then_action) if then_action != null else (ACT_OPTIONS[_then_opt.selected] if _then_opt else "move_up")
	return _str_to_cmd(s)

func get_then_action2() -> CommandBlock.CommandType:
	var s := str(then_action2) if then_action2 != null else (ACT_OPTIONS[_then2_opt.selected] if _then2_opt else "attack")
	return _str_to_cmd(s)

func get_else_action() -> CommandBlock.CommandType:
	var s := str(else_action) if else_action != null else (ACT_OPTIONS[_else_opt.selected] if _else_opt else "move_up")
	return _str_to_cmd(s)

func get_else_action2() -> CommandBlock.CommandType:
	var s := str(else_action2) if else_action2 != null else (ACT_OPTIONS[_else2_opt.selected] if _else2_opt else "attack")
	return _str_to_cmd(s)

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
	cb.repeat_count           = get_repeat_count()
	cb.check_direction        = get_check_direction()
	cb.check_condition        = get_check_condition()
	cb.use_compound_condition = use_compound_condition
	cb.check_direction2       = get_check_direction2()
	cb.check_condition2       = get_check_condition2()
	cb.then_action            = get_then_action()
	cb.use_compound_then      = use_compound_then
	cb.then_action2           = get_then_action2()
	cb.else_action            = get_else_action()
	cb.use_compound_else      = use_compound_else
	cb.else_action2           = get_else_action2()
	return cb
