extends CharacterBody2D
class_name Robot

signal action_completed

const TILE_SIZE = 64
const MOVE_SPEED = 4.0  # Tiles per second

enum Direction { UP, DOWN, LEFT, RIGHT }

var grid_position: Vector2i = Vector2i(0, 0)
var target_position: Vector2 = Vector2.ZERO
var is_moving: bool = false

func _ready() -> void:
	# Start at grid position (5, 5)
	grid_position = Vector2i(2,6)
	position = grid_to_world(grid_position)
	target_position = position
	print("Robot ready at grid position: ", grid_position)

func _physics_process(delta: float) -> void:
	if is_moving:
		# Smooth movement to target
		position = position.move_toward(target_position, MOVE_SPEED * TILE_SIZE * delta)
		
		# Check if reached target
		if position.distance_to(target_position) < 1.0:
			position = target_position
			is_moving = false
			action_completed.emit()
			print("Move completed. Now at: ", grid_position)

# === PUBLIC METHODS ===

func move_up() -> void:
	_move(Direction.UP)

func move_down() -> void:
	_move(Direction.DOWN)

func move_left() -> void:
	_move(Direction.LEFT)

func move_right() -> void:
	_move(Direction.RIGHT)

func _move(direction: Direction) -> void:
	if is_moving:
		print("Already moving, skipping command")
		return
	
	var offset = _direction_to_offset(direction)
	var new_grid_pos = grid_position + offset
	
	# Simple bounds checking (0-15 grid)
	if new_grid_pos.x < 0 or new_grid_pos.x > 15:
		print("Hit boundary!")
		action_completed.emit()
		return
	if new_grid_pos.y < 0 or new_grid_pos.y > 15:
		print("Hit boundary!")
		action_completed.emit()
		return
	
	# Valid move
	grid_position = new_grid_pos
	target_position = grid_to_world(grid_position)
	is_moving = true
	print("Moving to grid position: ", grid_position)

# === HELPER METHODS ===

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	# Center the grid (0,0) at world origin
	return Vector2(grid_pos) * 64 + Vector2(32, 32)

func _direction_to_offset(dir: Direction) -> Vector2i:
	match dir:
		Direction.UP:
			return Vector2i(0, -1)
		Direction.DOWN:
			return Vector2i(0, 1)
		Direction.LEFT:
			return Vector2i(-1, 0)
		Direction.RIGHT:
			return Vector2i(1, 0)
	return Vector2i.ZERO
