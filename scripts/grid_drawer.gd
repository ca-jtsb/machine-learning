extends Node2D
class_name GridDrawer


const GRID_SIZE = 64
const TILE_SIZE = 64

var grid_color = Color(0.3, 0.3, 0.3, 0.5)
var grid_line_color = Color(0.5, 0.5, 0.5, 0.3)

func _draw() -> void:
	# Draw grid tiles
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var pos = Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var rect = Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE))
			
			# Checkerboard pattern
			var color = grid_color
			if (x + y) % 2 == 0:
				color = color.lightened(0.1)
			
			draw_rect(rect, color, true)
			draw_rect(rect, grid_line_color, false, 1.0)
