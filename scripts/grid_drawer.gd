extends Node2D
class_name GridDrawer

## Clean grid — no checkerboard, just a dark background and subtle cell lines.
## Position this node at the top-left of where you want the grid to start.

const GRID_COLS : int = 9
const GRID_ROWS : int = 6
const TILE_SIZE : int = 80   # increased from 64 so grid fills more screen space

var bg_color   : Color = Color(0.18, 0.18, 0.20, 1.0)
var line_color : Color = Color(1.0,  1.0,  1.0,  0.08)

func _draw() -> void:
	var w : float = GRID_COLS * TILE_SIZE
	var h : float = GRID_ROWS * TILE_SIZE
	# Dark background
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), bg_color, true)
	# Subtle cell borders
	for y in range(GRID_ROWS):
		for x in range(GRID_COLS):
			draw_rect(
				Rect2(Vector2(x * TILE_SIZE, y * TILE_SIZE), Vector2(TILE_SIZE, TILE_SIZE)),
				line_color, false, 1.0
			)
