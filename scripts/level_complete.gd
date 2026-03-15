extends CanvasLayer

signal next_level_pressed

func _ready() -> void:
	$LevelCompletePanel/VBoxContainer/CenterContainer/NextButton.pressed.connect(_on_next_pressed)

func _on_next_pressed() -> void:
	next_level_pressed.emit()
