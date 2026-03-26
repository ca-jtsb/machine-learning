extends CanvasLayer
signal tutorial_finished

@onready var dialogue_text  : RichTextLabel = $DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var next_button    : Button        = $DialogueBox/MarginContainer/VBoxContainer/NextButton
@onready var pointer        : TextureRect   = $PointerArrow
@onready var dim_overlay    : ColorRect     = $DimOverlay

const CHARS_PER_SECOND : float = 40.0   # ← adjust this to taste

var _steps      : Array[Dictionary] = []
var _step_index : int  = 0
var _full_text  : String = ""
var _is_typing  : bool   = false

func _ready() -> void:
	next_button.pressed.connect(_on_next_pressed)
	pointer.visible = false

func setup(steps: Array[Dictionary]) -> void:
	_steps      = steps
	_step_index = 0
	_show_step(0)

func _show_step(i: int) -> void:
	if i >= _steps.size():
		_finish()
		return

	var step : Dictionary = _steps[i]
	_full_text = step.get("text", "")

	var pos = step.get("pointer_pos", null)
	if pos != null:
		pointer.visible  = true
		pointer.position = pos
	else:
		pointer.visible = false

	next_button.text = "Skip ▶" if _steps.size() > 1 else "Start ▶"
	next_button.disabled = false

	# Start typewriter
	dialogue_text.bbcode_enabled = true
	dialogue_text.text = _full_text      # set full text so BBCode is parsed
	dialogue_text.visible_ratio = 0.0    # but show none of it yet
	_is_typing = true
	_run_typewriter()

func _run_typewriter() -> void:
	var total_chars : int = dialogue_text.get_total_character_count()
	if total_chars == 0:
		_finish_typing()
		return

	var elapsed : float = 0.0
	while _is_typing:
		elapsed += get_process_delta_time()
		# Can't use await inside a while loop cleanly, so use a tween instead
		break

	# Use a Tween for smooth per-frame progress
	var tween := create_tween()
	tween.tween_property(
		dialogue_text, "visible_ratio",
		1.0, float(total_chars) / CHARS_PER_SECOND
	).from(0.0)
	tween.tween_callback(_finish_typing)

func _finish_typing() -> void:
	_is_typing = false
	dialogue_text.visible_ratio = 1.0
	# Update button to final label now that typing is done
	var is_last : bool = _step_index == _steps.size() - 1
	next_button.text = "Start ▶" if is_last else "Next ▶"

func _on_next_pressed() -> void:
	if _is_typing:
		# First press skips to end of current text
		_is_typing = false
		dialogue_text.visible_ratio = 1.0
		var is_last : bool = _step_index == _steps.size() - 1
		next_button.text = "Start ▶" if is_last else "Next ▶"
		return

	_step_index += 1
	_show_step(_step_index)

func _finish() -> void:
	emit_signal("tutorial_finished")
	queue_free()
