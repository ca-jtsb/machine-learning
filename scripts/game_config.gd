class_name GameConfig
extends Node

const FONT_PATH : String = "res://fonts/PressStart2P-Regular.ttf"  # change this

const FONT_SIZE_NORMAL : int = 15
const FONT_SIZE_SMALL  : int = 12
const FONT_SIZE_LARGE  : int = 18
const FONT_SIZE_TITLE  : int = 22

static func get_font() -> FontFile:
	if FONT_PATH != "" and ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH) as FontFile
	return null

static func apply(node: Control, size: int) -> void:
	var f := get_font()
	if f:
		node.add_theme_font_override("font", f)
	node.add_theme_font_size_override("font_size", size)
