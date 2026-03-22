extends PanelContainer
class_name RepeatIfElseBlock

signal changed

# ── Slot data ──────────────────────────────────────────────────────────────────
var repeat_count    : int     = 6
var repeat_fixed    : bool    = false

var check_direction : Variant = null   # null = dropdown | "UP"/"DOWN"/"LEFT"/"RIGHT"
var check_condition : Variant = null   # null = dropdown | "is_free"/"is_obstacle"

var use_compound_condition : bool    = false
var check_direction2       : Variant = null
var check_condition2       : Variant = null

var then_action      : Variant = null
var use_compound_then : bool   = false
var then_action2      : Variant = null

var else_action      : Variant = null
var use_compound_else : bool   = false
var else_action2      : Variant = null

# Attack direction overrides — "" means use current facing direction (pre-filled only)
var then_attack_dir  : String = ""
var then2_attack_dir : String = ""
var else_attack_dir  : String = ""
var else2_attack_dir : String = ""

const MAX_REPEAT : int = 50
const MIN_REPEAT : int = 1

# ── Short display labels ───────────────────────────────────────────────────────
# Directions shown as arrows in dropdown, stored as UP/DOWN/LEFT/RIGHT
const DIR_OPTIONS  : Array[String] = ["UP",   "DOWN", "LEFT", "RIGHT"]
const DIR_LABELS   : Array[String] = ["↑ UP", "↓ DN", "← LT", "→ RT"]

# Conditions shown as short words
const COND_OPTIONS : Array[String] = ["is_free",  "is_obstacle"]
const COND_LABELS  : Array[String] = ["free",     "obstacle"]

# Actions — just emoji + 1-2 chars
const ACT_OPTIONS  : Array[String] = ["move_up",  "move_down", "move_left", "move_right", "attack"]
const ACT_LABELS   : Array[String] = ["MOVE UP ↑",        "MOVE DOWN ↓",         "MOVE LEFT ←",         "MOVE RIGHT →",           "⚔"]

const COLOR_OUTER : Color = Color(0.95, 0.55, 0.05, 1.0)
const COLOR_INNER : Color = Color(0.80, 0.42, 0.02, 1.0)
const COLOR_TEXT  : Color = Color(1.0,  1.0,  1.0,  1.0)
const COLOR_VAL   : Color = Color(1.0,  1.0,  0.5,  1.0)
const COLOR_AND   : Color = Color(0.4,  0.9,  1.0,  1.0)

var _repeat_spin : SpinBox      = null
var _dir_opt     : OptionButton = null
var _cond_opt    : OptionButton = null
var _dir2_opt    : OptionButton = null
var _cond2_opt   : OptionButton = null
var _then_opt    : OptionButton = null
var _then2_opt   : OptionButton = null
var _else_opt    : OptionButton = null
var _else2_opt   : OptionButton = null
# Attack direction dropdowns — shown next to ⚔ when it is a blank (player-choosable) action
var _then_atk_dir_opt  : OptionButton = null
var _then2_atk_dir_opt : OptionButton = null
var _else_atk_dir_opt  : OptionButton = null
var _else2_atk_dir_opt : OptionButton = null

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Outer orange panel — expand to fill panel width, no fixed min-width
	var outer_style := StyleBoxFlat.new()
	outer_style.bg_color = COLOR_OUTER
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		outer_style.set("corner_radius_" + corner, 8)
	add_theme_stylebox_override("panel", outer_style)
	custom_minimum_size = Vector2(0, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var outer_margin := MarginContainer.new()
	outer_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:
		outer_margin.add_theme_constant_override("margin_" + side, 8 if side in ["left","right"] else 6)
	add_child(outer_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(vbox)

	# ── REPEAT header ─────────────────────────────────────────────────────────
	var repeat_row := HBoxContainer.new()
	repeat_row.add_theme_constant_override("separation", 5)
	vbox.add_child(repeat_row)

	_lbl(repeat_row, "↺  REPEAT", 14, COLOR_TEXT, true)

	_repeat_spin = SpinBox.new()
	_repeat_spin.min_value = MIN_REPEAT
	_repeat_spin.max_value = MAX_REPEAT
	_repeat_spin.step      = 1
	_repeat_spin.value     = clamp(repeat_count, MIN_REPEAT, MAX_REPEAT)
	_repeat_spin.custom_minimum_size = Vector2(72, 0)
	_repeat_spin.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_repeat_spin.editable  = not repeat_fixed
	_repeat_spin.suffix    = "×"
	_repeat_spin.value_changed.connect(func(_v): changed.emit())
	_repeat_spin.get_line_edit().text_submitted.connect(_on_repeat_text_submitted)
	_repeat_spin.get_line_edit().focus_exited.connect(_on_repeat_focus_exited)
	repeat_row.add_child(_repeat_spin)

	# ── Inner panel ───────────────────────────────────────────────────────────
	var inner_panel := PanelContainer.new()
	inner_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var inner_style := StyleBoxFlat.new()
	inner_style.bg_color = COLOR_INNER
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		inner_style.set("corner_radius_" + corner, 5)
	inner_panel.add_theme_stylebox_override("panel", inner_style)
	vbox.add_child(inner_panel)

	var inner_margin := MarginContainer.new()
	inner_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left","right","top","bottom"]:
		inner_margin.add_theme_constant_override("margin_" + side, 7 if side in ["left","right"] else 5)
	inner_panel.add_child(inner_margin)

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 6)
	inner_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner_margin.add_child(inner_vbox)

	# ── IF row (primary condition) ────────────────────────────────────────────
	var if_row := _make_hbox()
	inner_vbox.add_child(if_row)
	_lbl(if_row, "if:", 12, COLOR_TEXT)

	if check_direction == null:
		_dir_opt = _make_dropdown(DIR_LABELS)
		if_row.add_child(_dir_opt)
		_dir_opt.item_selected.connect(func(_i): changed.emit())
	else:
		if_row.add_child(_make_val_label(_dir_display(str(check_direction))))

	_lbl(if_row, "==", 12, COLOR_VAL)

	if check_condition == null:
		_cond_opt = _make_dropdown(COND_LABELS)
		if_row.add_child(_cond_opt)
		_cond_opt.item_selected.connect(func(_i): changed.emit())
	else:
		if_row.add_child(_make_val_label(_cond_display(str(check_condition))))

	# ── Compound condition — second line ──────────────────────────────────────
	if use_compound_condition:
		var and_row := _make_hbox()
		inner_vbox.add_child(and_row)
		_lbl(and_row, "&&", 12, COLOR_AND, true)
		_lbl(and_row, "dir:", 12, COLOR_TEXT)

		if check_direction2 == null:
			_dir2_opt = _make_dropdown(DIR_LABELS)
			and_row.add_child(_dir2_opt)
			_dir2_opt.item_selected.connect(func(_i): changed.emit())
		else:
			and_row.add_child(_make_val_label(_dir_display(str(check_direction2))))

		_lbl(and_row, "==", 12, COLOR_VAL)

		if check_condition2 == null:
			_cond2_opt = _make_dropdown(COND_LABELS)
			and_row.add_child(_cond2_opt)
			_cond2_opt.item_selected.connect(func(_i): changed.emit())
		else:
			and_row.add_child(_make_val_label(_cond_display(str(check_condition2))))

	# ── THEN row ──────────────────────────────────────────────────────────────
	var then_row := _make_hbox()
	inner_vbox.add_child(then_row)
	_lbl(then_row, "then:", 12, COLOR_TEXT)

	if then_action == null:
		_then_opt = _make_dropdown(ACT_LABELS)
		then_row.add_child(_then_opt)
		_then_opt.item_selected.connect(func(i):
			_refresh_atk_dir(_then_opt, _then_atk_dir_opt, i)
			changed.emit())
		_then_atk_dir_opt = _make_dropdown(DIR_LABELS)
		_then_atk_dir_opt.visible = false
		then_row.add_child(_then_atk_dir_opt)
		_then_atk_dir_opt.item_selected.connect(func(_i): changed.emit())
	else:
		then_row.add_child(_make_val_label(_act_display(str(then_action))))
		if str(then_action) == "attack" and then_attack_dir != "":
			then_row.add_child(_make_val_label(_dir_display(then_attack_dir)))

	if use_compound_then:
		_lbl(then_row, "&&", 12, COLOR_AND, true)
		if then_action2 == null:
			_then2_opt = _make_dropdown(ACT_LABELS)
			then_row.add_child(_then2_opt)
			_then2_opt.item_selected.connect(func(i):
				_refresh_atk_dir(_then2_opt, _then2_atk_dir_opt, i)
				changed.emit())
			_then2_atk_dir_opt = _make_dropdown(DIR_LABELS)
			_then2_atk_dir_opt.visible = false
			then_row.add_child(_then2_atk_dir_opt)
			_then2_atk_dir_opt.item_selected.connect(func(_i): changed.emit())
		else:
			then_row.add_child(_make_val_label(_act_display(str(then_action2))))
			if str(then_action2) == "attack" and then2_attack_dir != "":
				then_row.add_child(_make_val_label(_dir_display(then2_attack_dir)))

	# ── ELSE row ──────────────────────────────────────────────────────────────
	var else_row := _make_hbox()
	inner_vbox.add_child(else_row)
	_lbl(else_row, "else:", 12, COLOR_TEXT)

	if else_action == null:
		_else_opt = _make_dropdown(ACT_LABELS)
		else_row.add_child(_else_opt)
		_else_opt.item_selected.connect(func(i):
			_refresh_atk_dir(_else_opt, _else_atk_dir_opt, i)
			changed.emit())
		_else_atk_dir_opt = _make_dropdown(DIR_LABELS)
		_else_atk_dir_opt.visible = false
		else_row.add_child(_else_atk_dir_opt)
		_else_atk_dir_opt.item_selected.connect(func(_i): changed.emit())
	else:
		else_row.add_child(_make_val_label(_act_display(str(else_action))))
		if str(else_action) == "attack" and else_attack_dir != "":
			else_row.add_child(_make_val_label(_dir_display(else_attack_dir)))

	if use_compound_else:
		_lbl(else_row, "&&", 12, COLOR_AND, true)
		if else_action2 == null:
			_else2_opt = _make_dropdown(ACT_LABELS)
			else_row.add_child(_else2_opt)
			_else2_opt.item_selected.connect(func(i):
				_refresh_atk_dir(_else2_opt, _else2_atk_dir_opt, i)
				changed.emit())
			_else2_atk_dir_opt = _make_dropdown(DIR_LABELS)
			_else2_atk_dir_opt.visible = false
			else_row.add_child(_else2_atk_dir_opt)
			_else2_atk_dir_opt.item_selected.connect(func(_i): changed.emit())
		else:
			else_row.add_child(_make_val_label(_act_display(str(else_action2))))
			if str(else_action2) == "attack" and else2_attack_dir != "":
				else_row.add_child(_make_val_label(_dir_display(else_attack_dir)))

# ── Attack direction visibility toggle ────────────────────────────────────────
# Shows the direction dropdown next to ⚔ only when attack is selected
func _refresh_atk_dir(act_opt: OptionButton, dir_opt: OptionButton, selected_idx: int) -> void:
	if dir_opt == null: return
	dir_opt.visible = (ACT_OPTIONS[selected_idx] == "attack")

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

# ── Display helpers ────────────────────────────────────────────────────────────
func _dir_display(d: String) -> String:
	match d:
		"UP":    return "↑ UP"
		"DOWN":  return "↓ DN"
		"LEFT":  return "← LT"
		"RIGHT": return "→ RT"
	return d

func _cond_display(c: String) -> String:
	match c:
		"is_free":     return "free"
		"is_obstacle": return "wall"
	return c

func _act_display(a: String) -> String:
	match a:
		"move_up":    return "↑"
		"move_down":  return "↓"
		"move_left":  return "←"
		"move_right": return "→"
		"attack":     return "⚔"
	return a

# ── UI factories ───────────────────────────────────────────────────────────────
func _make_hbox() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return h

func _lbl(parent: Node, text: String, font_sz: int, color: Color, bold: bool = false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", font_sz)
	if bold:
		pass  # bold via theme not easily set at runtime; kept for future
	parent.add_child(l)

func _make_val_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", COLOR_VAL)
	l.add_theme_font_size_override("font_size", 12)
	return l

func _make_dropdown(options: Array[String]) -> OptionButton:
	var ob := OptionButton.new()
	ob.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	ob.custom_minimum_size = Vector2(0, 26)
	ob.add_theme_font_size_override("font_size", 12)
	for opt in options:
		ob.add_item(opt)
	return ob

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
	# Pass attack direction overrides (from blueprint pre-fill or player dropdown)
	cb.then_attack_dir  = _get_atk_dir(then_action,  then_attack_dir,  _then_atk_dir_opt)
	cb.then2_attack_dir = _get_atk_dir(then_action2, then2_attack_dir, _then2_atk_dir_opt)
	cb.else_attack_dir  = _get_atk_dir(else_action,  else_attack_dir,  _else_atk_dir_opt)
	cb.else2_attack_dir = _get_atk_dir(else_action2, else2_attack_dir, _else2_atk_dir_opt)
	return cb

func _get_atk_dir(action: Variant, prefill: String, opt: OptionButton) -> String:
	# Pre-filled attack dir takes priority
	if prefill != "": return prefill
	# Player-chosen: only relevant if action dropdown has ⚔ selected
	if opt != null and opt.visible:
		return DIR_OPTIONS[opt.selected]
	return ""
