extends CharacterBody2D
class_name Robot

signal action_completed

const TILE_SIZE  = 64
const MOVE_SPEED = 8.0   # tiles per second — raise for faster sliding

enum Direction { UP, DOWN, LEFT, RIGHT }

# Grid dimensions must match your TileMapLayer setup
const GRID_COLS : int = 9
const GRID_ROWS : int = 6

var grid_position   : Vector2i = Vector2i(1, 4)  # starting cell (col, row)
var target_position : Vector2  = Vector2.ZERO
var is_moving       : bool     = false

# Fetched at runtime — node must be named "TileMapLayer" and be a sibling of Robot
@onready var tilemap : TileMapLayer = get_parent().get_node("GridMap")

func _ready() -> void:
	position        = grid_to_world(grid_position)
	target_position = position

func _physics_process(delta: float) -> void:
	if is_moving:
		position = position.move_toward(target_position, MOVE_SPEED * TILE_SIZE * delta)
		if position.distance_to(target_position) < 1.0:
			position  = target_position
			is_moving = false

# ── Public API (called by CommandBlock.execute) ───────────────────────────────
func move_up()    -> void: await _slide(Direction.UP)
func move_down()  -> void: await _slide(Direction.DOWN)
func move_left()  -> void: await _slide(Direction.LEFT)
func move_right() -> void: await _slide(Direction.RIGHT)

# ── Slide until blocked ───────────────────────────────────────────────────────
func _slide(dir: Direction) -> void:
	if is_moving:
		return

	var offset : Vector2i = _dir_to_offset(dir)

	while true:
		var next_cell : Vector2i = grid_position + offset

		if _is_blocked(next_cell):
			break          # wall or boundary ahead — stop

		# Move one step
		grid_position   = next_cell
		target_position = grid_to_world(grid_position)
		is_moving       = true

		await _wait_for_arrival()   # smooth animation per tile

	action_completed.emit()

func _wait_for_arrival() -> void:
	while is_moving:
		await get_tree().process_frame

# ── Obstacle detection ────────────────────────────────────────────────────────
func _is_blocked(cell: Vector2i) -> bool:
	# Out-of-bounds
	if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
		return true

	# Any painted tile in the TileMapLayer = wall
	# get_cell_source_id() returns -1 for empty cells
	if tilemap and tilemap.get_cell_source_id(cell) != -1:
		return true

	return false

# ── Helpers ───────────────────────────────────────────────────────────────────
func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE + Vector2(TILE_SIZE * 0.5, TILE_SIZE * 0.5)

func _dir_to_offset(dir: Direction) -> Vector2i:
	match dir:
		Direction.UP:    return Vector2i( 0, -1)
		Direction.DOWN:  return Vector2i( 0,  1)
		Direction.LEFT:  return Vector2i(-1,  0)
		Direction.RIGHT: return Vector2i( 1,  0)
	return Vector2i.ZERO
