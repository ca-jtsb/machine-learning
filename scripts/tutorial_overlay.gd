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
var _float_head     : TextureRect     = null

const CHARS_PER_SECOND : float = 40.0

# ── Screen size (update if your viewport changes) ─────────────────────────────
const SCREEN_W : float = 1152.0
const SCREEN_H : float = 648.0

# ── Float box dimensions ───────────────────────────────────────────────────────
const FLOAT_BOX_W  : float = 320.0
const FLOAT_BOX_H  : float = 150.0
const HEAD_SIZE    : float = 56.0
const MARGIN       : float = 12.0
const PTR_OFFSET   : float = 60.0

# ══════════════════════════════════════════════════════════════════════════════
# POINTER CONFIG
#
#   POINTER_TEXTURE      — path to your PNG asset.
#                          e.g. "res://assets/UI/arrow.png"
#                          Set to "" to keep whatever texture is already on the
#                          $PointerArrow node in the scene file.
#
#   POINTER_SIZE         — display size of the pointer in pixels.
#
#   POINTER_ROTATION     — base rotation in DEGREES applied to every step.
#                            0   = no rotation (image used as-is).
#                            90  = 90° clockwise.
#                           -90  = 90° counter-clockwise.
#                            180 = upside-down.
#                          Per-step override: add  "pointer_rotation": <degrees>
#                          to any step dict to override just that one step.
#
#   POINTER_PIVOT        — normalised pivot for rotation and the bob animation.
#                          Vector2(0.5, 0.5) = centre (default).
#                          Vector2(0.5, 0.0) = top-centre   → good for a ↓ arrow.
#                          Vector2(0.5, 1.0) = bottom-centre → good for a ↑ arrow.
#
#   POINTER_BOB_DISTANCE — pixels the pointer travels per half-swing.
#                          The bob direction follows the pointer's rotated forward
#                          axis so it always pushes the tip toward its target.
#                          Set to 0.0 to disable the animation entirely.
#
#   POINTER_BOB_SPEED    — seconds for one half-swing (peak → trough).
#                          0.35–0.55 looks natural. Smaller = faster.
# ══════════════════════════════════════════════════════════════════════════════
const POINTER_TEXTURE      : String  = "res://assets/UI/pointer.png"               # e.g. "res://assets/UI/arrow.png"
const POINTER_SIZE         : Vector2 = Vector2(48, 48)
const POINTER_ROTATION     : float   = 0.0              # degrees — global default
const POINTER_PIVOT        : Vector2 = Vector2(0.5, 0.5)
const POINTER_BOB_DISTANCE : float   = 10.0             # pixels
const POINTER_BOB_SPEED    : float   = 0.4              # seconds per half-swing

# ── Pointer animation state ────────────────────────────────────────────────────
var _pointer_tween  : Tween   = null
var _pointer_origin : Vector2 = Vector2.ZERO

# ── Step state ────────────────────────────────────────────────────────────────
var _steps      : Array[Dictionary] = []
var _step_index : int    = 0
var _full_text  : String = ""
var _is_typing  : bool   = false
var _active_box : PanelContainer = null

# ──────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	pointer.visible = false

	# Apply PNG asset if one is configured
	if POINTER_TEXTURE != "":
		if ResourceLoader.exists(POINTER_TEXTURE):
			pointer.texture = load(POINTER_TEXTURE)
		else:
			push_warning("TutorialOverlay: POINTER_TEXTURE not found: " + POINTER_TEXTURE)

	# Size, stretch, pivot
	pointer.custom_minimum_size = POINTER_SIZE
	pointer.size                = POINTER_SIZE
	pointer.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	pointer.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pointer.pivot_offset        = POINTER_SIZE * POINTER_PIVOT

	_build_float_box()

# ── Pointer helpers ────────────────────────────────────────────────────────────

func _stop_pointer() -> void:
	if _pointer_tween and _pointer_tween.is_valid():
		_pointer_tween.kill()
	_pointer_tween = null
	pointer.visible = false

func _start_pointer(pos: Vector2, rot_deg: float) -> void:
	_pointer_origin          = pos
	pointer.position         = pos
	pointer.rotation_degrees = rot_deg
	pointer.visible          = true

	if POINTER_BOB_DISTANCE <= 0.0:
		return

	# Compute bob direction along the pointer's rotated forward axis so the
	# animation always nudges the tip toward whatever it is pointing at.
	var angle_rad  : float   = deg_to_rad(rot_deg)
	var bob_dir    : Vector2 = Vector2(sin(angle_rad), -cos(angle_rad))
	var bob_offset : Vector2 = bob_dir * POINTER_BOB_DISTANCE

	if _pointer_tween and _pointer_tween.is_valid():
		_pointer_tween.kill()

	_pointer_tween = create_tween()
	_pointer_tween.set_loops()
	_pointer_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pointer_tween.tween_property(pointer, "position",
		_pointer_origin + bob_offset, POINTER_BOB_SPEED)
	_pointer_tween.tween_property(pointer, "position",
		_pointer_origin - bob_offset, POINTER_BOB_SPEED)

# ── Build the floating dialogue box once at startup ────────────────────────────
func _build_float_box() -> void:
	var hbox := HBoxContainer.new()
	hbox.name = "FloatHBox"
	hbox.add_theme_constant_override("separation", 6)
	hbox.visible = false
	add_child(hbox)

	_float_head = TextureRect.new()
	_float_head.texture      = $AssistantSprite.texture
	_float_head.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_float_head.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_float_head.custom_minimum_size = Vector2(HEAD_SIZE, HEAD_SIZE)
	_float_head.size         = Vector2(HEAD_SIZE, HEAD_SIZE)
	_float_head.clip_contents = true
	hbox.add_child(_float_head)

	_float_box = PanelContainer.new()
	_float_box.custom_minimum_size = Vector2(FLOAT_BOX_W, FLOAT_BOX_H)
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.09, 0.09, 0.15, 0.96)
	style.border_color = Color(0.95, 0.55, 0.05, 1.0)
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
	_float_text.bbcode_enabled = true
	_float_text.fit_content    = true
	_float_text.scroll_active  = false
	_float_text.custom_minimum_size = Vector2(0, 60)
	vbox.add_child(_float_text)

	_float_next_btn = Button.new()
	_float_next_btn.custom_minimum_size   = Vector2(100, 32)
	_float_next_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	_float_next_btn.text = "Next ▶"
	_float_next_btn.pressed.connect(_on_next_pressed)
	vbox.add_child(_float_next_btn)

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
	var box_pos                = step.get("box_position", null)
	var ptr_pos                = step.get("pointer_pos", null)

	# Per-step rotation override; falls back to the global POINTER_ROTATION constant.
	var ptr_rot : float = float(step.get("pointer_rotation", POINTER_ROTATION))

	# ── Pointer ───────────────────────────────────────────────────────────────
	_stop_pointer()
	if ptr_pos != null:
		_start_pointer(ptr_pos, ptr_rot)

	# ── Decide which box to use ────────────────────────────────────────────────
	if typeof(box_pos) == TYPE_STRING and box_pos == "near_pointer" and ptr_pos != null:
		_show_default_box(false)
		_show_float_box(true, ptr_pos)
		_active_box = _float_box
		_type_into(_float_text, _float_next_btn, i)

	elif typeof(box_pos) == TYPE_VECTOR2:
		_show_default_box(false)
		_show_float_box_at(true, box_pos)
		_active_box = _float_box
		_type_into(_float_text, _float_next_btn, i)

	else:
		_show_float_box(false, Vector2.ZERO)
		_show_default_box(true)
		_active_box = null
		_type_into(dialogue_text, next_button, i)

# ── Toggle default (bottom) box and assistant sprite ──────────────────────────
func _show_default_box(visible_flag: bool) -> void:
	dialogue_box.visible = visible_flag
	assistant.visible    = visible_flag

# ── Float box auto-positioned relative to the pointer ─────────────────────────
func _show_float_box(visible_flag: bool, ptr_pos: Vector2) -> void:
	var hbox : HBoxContainer = _float_box.get_meta("hbox")
	hbox.visible = visible_flag
	if not visible_flag:
		return

	var total_w : float = HEAD_SIZE + 6.0 + FLOAT_BOX_W
	var total_h : float = FLOAT_BOX_H

	var x : float = ptr_pos.x - total_w - PTR_OFFSET
	var y : float = ptr_pos.y - total_h * 0.5

	if x < MARGIN:
		x = ptr_pos.x + PTR_OFFSET

	y = clamp(y, MARGIN, SCREEN_H - total_h - MARGIN)
	x = clamp(x, MARGIN, SCREEN_W - total_w - MARGIN)

	hbox.position = Vector2(x, y)

# ── Float box placed at an explicit Vector2 position ──────────────────────────
func _show_float_box_at(visible_flag: bool, pos: Vector2) -> void:
	var hbox : HBoxContainer = _float_box.get_meta("hbox")
	hbox.visible = visible_flag
	if not visible_flag:
		return

	var total_w : float = HEAD_SIZE + 6.0 + FLOAT_BOX_W
	var total_h : float = FLOAT_BOX_H

	hbox.position = Vector2(
		clamp(pos.x, MARGIN, SCREEN_W - total_w - MARGIN),
		clamp(pos.y, MARGIN, SCREEN_H - total_h - MARGIN)
	)

# ── Typewriter ────────────────────────────────────────────────────────────────
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
	tween.tween_property(rtl, "visible_ratio",
		1.0, float(total_chars) / CHARS_PER_SECOND).from(0.0)
	tween.tween_callback(func(): _finish_typing(rtl, btn, is_last))

func _finish_typing(rtl: RichTextLabel, btn: Button, is_last: bool) -> void:
	_is_typing        = false
	rtl.visible_ratio = 1.0
	btn.text = "Start ▶" if is_last else "Next ▶"

# ── Next / Skip button handler ─────────────────────────────────────────────────
func _on_next_pressed() -> void:
	var step    : Dictionary = _steps[_step_index]
	var box_pos              = step.get("box_position", null)
	var ptr_pos              = step.get("pointer_pos", null)
	var use_float : bool = (typeof(box_pos) == TYPE_STRING and box_pos == "near_pointer" and ptr_pos != null) \
						or (typeof(box_pos) == TYPE_VECTOR2)
	var rtl : RichTextLabel = _float_text     if use_float else dialogue_text
	var btn : Button        = _float_next_btn if use_float else next_button
	var is_last : bool      = _step_index == _steps.size() - 1

	if _is_typing:
		_is_typing        = false
		rtl.visible_ratio = 1.0
		btn.text = "Start ▶" if is_last else "Next ▶"
		return

	_step_index += 1
	_show_step(_step_index)

func _finish() -> void:
	_stop_pointer()
	emit_signal("tutorial_finished")
	queue_free()
