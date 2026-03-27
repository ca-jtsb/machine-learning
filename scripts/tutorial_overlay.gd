extends CanvasLayer
signal tutorial_finished

@onready var dialogue_box   : PanelContainer = $DialogueBox
@onready var dialogue_text  : RichTextLabel  = $DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var next_button    : Button         = $DialogueBox/MarginContainer/VBoxContainer/NextButton
@onready var pointer        : TextureRect    = $PointerArrow
@onready var dim_overlay    : ColorRect      = $DimOverlay
@onready var assistant      : TextureRect    = $AssistantSprite

# ── Floating box (built at runtime, shown near pointer) ────────────────────────
var _float_box      : PanelContainer  = null
var _float_text     : RichTextLabel   = null
var _float_next_btn : Button          = null
var _float_head     : TextureRect     = null   # small character head beside float box

const CHARS_PER_SECOND : float = 40.0

# ── Screen size (update if your viewport changes) ─────────────────────────────
const SCREEN_W : float = 1152.0
const SCREEN_H : float = 648.0

# ── Float box dimensions ───────────────────────────────────────────────────────
const FLOAT_BOX_W  : float = 320.0
const FLOAT_BOX_H  : float = 150.0
const HEAD_SIZE    : float = 56.0    # square crop of the assistant sprite
const MARGIN       : float = 12.0    # gap from pointer / screen edges
const PTR_OFFSET   : float = 60.0    # how far from the pointer tip the box sits

var _steps      : Array[Dictionary] = []
var _step_index : int    = 0
var _full_text  : String = ""
var _is_typing  : bool   = false
var _active_box : PanelContainer = null   # whichever box is currently shown

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	pointer.visible = false
	_build_float_box()

# ── Build the floating dialogue box once at startup ────────────────────────────
func _build_float_box() -> void:
	# Outer HBox: [head] [panel]
	var hbox := HBoxContainer.new()
	hbox.name = "FloatHBox"
	hbox.add_theme_constant_override("separation", 6)
	hbox.visible = false
	add_child(hbox)

	# ── Character head (cropped square of the same boss_sprite texture) ────────
	_float_head = TextureRect.new()
	_float_head.texture     = $AssistantSprite.texture
	_float_head.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_float_head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_float_head.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
	_float_head.size = Vector2(HEAD_SIZE, HEAD_SIZE)
	# Clip to a square so only the face shows
	_float_head.clip_contents = true
	hbox.add_child(_float_head)

	# ── Panel box ─────────────────────────────────────────────────────────────
	_float_box = PanelContainer.new()
	_float_box.custom_minimum_size = Vector2(FLOAT_BOX_W, FLOAT_BOX_H)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.09, 0.09, 0.15, 0.96)
	style.border_color = Color(0.95, 0.55, 0.05, 1.0)   # orange to stand out
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 2)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		style.set("corner_radius_" + corner, 8)
	_float_box.add_theme_stylebox_override("panel", style)
	hbox.add_child(_float_box)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	_float_box.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	_float_text = RichTextLabel.new()
	_float_text.bbcode_enabled  = true
	_float_text.fit_content     = true
	_float_text.scroll_active   = false
	_float_text.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(_float_text)

	_float_next_btn = Button.new()
	_float_next_btn.custom_minimum_size = Vector2(100, 32)
	_float_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_float_next_btn.text = "Next ▶"
	_float_next_btn.pressed.connect(_on_next_pressed)
	vbox.add_child(_float_next_btn)

	# Keep a reference to the hbox so we can move/hide it
	_float_box.set_meta("hbox", hbox)

# ── Public API ─────────────────────────────────────────────────────────────────
func setup(steps: Array[Dictionary]) -> void:
	_steps      = steps
	_step_index = 0
	_show_step(0)

# ── Show one step ──────────────────────────────────────────────────────────────
func _show_step(i: int) -> void:
	if i >= _steps.size():
		_finish()
		return

	var step      : Dictionary = _steps[i]
	_full_text                 = step.get("text", "")
	var use_float : bool       = step.get("box_position", "") == "near_pointer"
	var ptr_pos                = step.get("pointer_pos", null)

	# ── Pointer ───────────────────────────────────────────────────────────────
	if ptr_pos != null:
		pointer.visible  = true
		pointer.position = ptr_pos
	else:
		pointer.visible = false

	# ── Choose which box to drive ──────────────────────────────────────────────
	if use_float and ptr_pos != null:
		_show_default_box(false)
		_show_float_box(true, ptr_pos)
		_active_box = _float_box
		_type_into(_float_text, _float_next_btn, i)
	else:
		_show_float_box(false, Vector2.ZERO)
		_show_default_box(true)
		_active_box = null   # default box drives itself via @onready refs
		_type_into(dialogue_text, next_button, i)

# ── Toggle default (bottom) box and assistant sprite ─────────────────────────
func _show_default_box(visible_flag: bool) -> void:
	dialogue_box.visible = visible_flag
	assistant.visible    = visible_flag

# ── Toggle and position the floating box ──────────────────────────────────────
func _show_float_box(visible_flag: bool, ptr_pos: Vector2) -> void:
	var hbox : HBoxContainer = _float_box.get_meta("hbox")
	hbox.visible = visible_flag
	if not visible_flag: return

	# Total width = head + gap + box
	var total_w : float = HEAD_SIZE + 6.0 + FLOAT_BOX_W
	var total_h : float = FLOAT_BOX_H

	# Try to place box to the LEFT of the pointer first, then right, then above
	var x : float = ptr_pos.x - total_w - PTR_OFFSET
	var y : float = ptr_pos.y - total_h * 0.5

	if x < MARGIN:
		# Place to the RIGHT instead
		x = ptr_pos.x + PTR_OFFSET

	# Clamp vertically so it stays on screen
	y = clamp(y, MARGIN, SCREEN_H - total_h - MARGIN)
	# Clamp horizontally
	x = clamp(x, MARGIN, SCREEN_W - total_w - MARGIN)

	hbox.position = Vector2(x, y)

# ── Typewriter into whichever RichTextLabel is active ─────────────────────────
func _type_into(rtl: RichTextLabel, btn: Button, step_i: int) -> void:
	var is_last : bool = step_i == _steps.size() - 1
	btn.text     = "Skip ▶"
	btn.disabled = false

	rtl.bbcode_enabled = true
	rtl.text           = _full_text
	rtl.visible_ratio  = 0.0
	_is_typing         = true

	var total_chars : int = rtl.get_total_character_count()
	if total_chars == 0:
		_finish_typing(rtl, btn, is_last)
		return

	var tween := create_tween()
	tween.tween_property(
		rtl, "visible_ratio",
		1.0, float(total_chars) / CHARS_PER_SECOND
	).from(0.0)
	tween.tween_callback(func(): _finish_typing(rtl, btn, is_last))

func _finish_typing(rtl: RichTextLabel, btn: Button, is_last: bool) -> void:
	_is_typing            = false
	rtl.visible_ratio     = 1.0
	btn.text = "Start ▶" if is_last else "Next ▶"

# ── Next / Skip button handler ─────────────────────────────────────────────────
func _on_next_pressed() -> void:
	# Determine which rtl+btn pair is active
	var step      : Dictionary = _steps[_step_index]
	var use_float : bool       = step.get("box_position", "") == "near_pointer" \
								 and step.get("pointer_pos", null) != null
	var rtl : RichTextLabel = _float_text  if use_float else dialogue_text
	var btn : Button        = _float_next_btn if use_float else next_button
	var is_last : bool      = _step_index == _steps.size() - 1

	if _is_typing:
		# First press: skip to end of current text
		_is_typing        = false
		rtl.visible_ratio = 1.0
		btn.text = "Start ▶" if is_last else "Next ▶"
		return

	_step_index += 1
	_show_step(_step_index)

func _finish() -> void:
	emit_signal("tutorial_finished")
	queue_free()
