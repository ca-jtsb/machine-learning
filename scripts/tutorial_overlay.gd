extends CanvasLayer

signal tutorial_finished

@onready var dialogue_text  : RichTextLabel = $DialogueBox/MarginContainer/VBoxContainer/DialogueText
@onready var next_button    : Button        = $DialogueBox/MarginContainer/VBoxContainer/NextButton
@onready var pointer        : TextureRect   = $PointerArrow
@onready var dim_overlay    : ColorRect     = $DimOverlay

# ── Tutorial steps ─────────────────────────────────────────────────────────────
# Each entry: { "text": "...", "pointer_pos": Vector2(...) or null }
# pointer_pos is in SCREEN coordinates. Use null to hide the pointer.
# You fill in the text strings — placeholders are provided below.

var _steps : Array[Dictionary] = []
var _step_index : int = 0

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
	dialogue_text.text = step.get("text", "")

	var pos = step.get("pointer_pos", null)
	if pos != null:
		pointer.visible  = true
		pointer.position = pos
	else:
		pointer.visible = false

	# Change Next button text on last step
	next_button.text = "Start ▶" if i == _steps.size() - 1 else "Next ▶"

func _on_next_pressed() -> void:
	_step_index += 1
	_show_step(_step_index)

func _finish() -> void:
	emit_signal("tutorial_finished")
	queue_free()
