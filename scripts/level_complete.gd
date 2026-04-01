extends CanvasLayer

signal next_level_pressed

func _ready() -> void:
	$LevelCompletePanel/VBoxContainer/CenterContainer/NextButton.pressed.connect(_on_next_pressed)

func set_attempts(level_label: String, count: int) -> void:
	var lbl := $LevelCompletePanel/VBoxContainer/AttemptsLabel
	if count <= 1:
		lbl.text = "%s — First try! 🎉" % level_label
	else:
		lbl.text = "%s — %d attempt%s" % [level_label, count, "s" if count != 1 else ""]

func _on_next_pressed() -> void:
	next_level_pressed.emit()
