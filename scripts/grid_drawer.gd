extends Node2D
class_name GridDrawer

const GRID_COLS : int = 9
const GRID_ROWS : int = 6
const TILE_SIZE : int = 64

var color_a    : Color = Color(0.30, 0.30, 0.30, 0.5)
var color_b    : Color = Color(0.35, 0.35, 0.35, 0.5)  # checkerboard alternate
var line_color : Color = Color(0.50, 0.50, 0.50, 0.3)

func _draw() -> void:
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			var pos  : Vector2 = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var rect : Rect2   = Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))
			var fill : Color   = color_b if (x + y) % 2 == 0 else color_a
			draw_rect(rect, fill, true)
			draw_rect(rect, line_color, false, 1.0)
