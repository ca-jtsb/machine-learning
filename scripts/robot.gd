extends CharacterBody2D
class_name Robot

signal action_completed
signal hit_wall   # emitted when robot tries to move into a wall during Phase 2 stepping

const TILE_SIZE  : int   = 88
const MOVE_SPEED : float = 6.0

enum Direction { UP, DOWN, LEFT, RIGHT }

const GRID_COLS : int = 9
const GRID_ROWS : int = 6

var grid_position   : Vector2i = Vector2i(0, 5)
var target_position : Vector2  = Vector2.ZERO
var is_moving       : bool     = false
var facing_dir      : Direction = Direction.RIGHT

var block_manager : BlockManager = null

var _body_rect     : ColorRect = null
var _dir_indicator : ColorRect = null

func _ready() -> void:
	z_index = 10
	_build_visuals()
	position        = grid_to_world(grid_position)
	target_position = position

func _build_visuals() -> void:
	_body_rect          = ColorRect.new()
	_body_rect.size     = Vector2(TILE_SIZE - 12, TILE_SIZE - 12)
	_body_rect.position = Vector2(6, 6)
	_body_rect.color    = Color(0.9, 0.15, 0.15)
	add_child(_body_rect)
	_dir_indicator          = ColorRect.new()
	_dir_indicator.size     = Vector2(14, 14)
	_dir_indicator.color    = Color(1, 1, 1, 0.9)
	add_child(_dir_indicator)
	_update_dir_indicator()

func _update_dir_indicator() -> void:
	if _dir_indicator == null:
		return
	var half : float = TILE_SIZE / 2.0
	match facing_dir:
		Direction.UP:    _dir_indicator.position = Vector2(half - 7, 8)
		Direction.DOWN:  _dir_indicator.position = Vector2(half - 7, TILE_SIZE - 22)
		Direction.LEFT:  _dir_indicator.position = Vector2(8,        half - 7)
		Direction.RIGHT: _dir_indicator.position = Vector2(TILE_SIZE - 22, half - 7)

func _physics_process(delta: float) -> void:
	if is_moving:
		position = position.move_toward(target_position, MOVE_SPEED * TILE_SIZE * delta)
		if position.distance_to(target_position) < 1.0:
			position  = target_position
			is_moving = false

# ── Public API — slide until wall (original mechanic) ─────────────────────────
func move_up()    -> void: await _slide(Direction.UP);    action_completed.emit()
func move_down()  -> void: await _slide(Direction.DOWN);  action_completed.emit()
func move_left()  -> void: await _slide(Direction.LEFT);  action_completed.emit()
func move_right() -> void: await _slide(Direction.RIGHT); action_completed.emit()
func attack()     -> void: await _do_attack();            action_completed.emit()

# ── Silent slide versions (used inside LOOP/APPEND) ───────────────────────────
func move_up_silent()    -> void: await _slide(Direction.UP)
func move_down_silent()  -> void: await _slide(Direction.DOWN)
func move_left_silent()  -> void: await _slide(Direction.LEFT)
func move_right_silent() -> void: await _slide(Direction.RIGHT)
func attack_silent()     -> void: await _do_attack()
func attack_silent_dir(dir: Direction) -> void:
	facing_dir = dir
	_update_dir_indicator()
	await _do_attack()

# ── Per-cell movement (used inside REPEAT-IF-ELSE blocks) ─────────────────────
# Moves exactly ONE tile in the given direction. If blocked, stays put.
# Does not emit action_completed (caller handles the signal).
func move_one_up()    -> void: await _step_one(Direction.UP)
func move_one_down()  -> void: await _step_one(Direction.DOWN)
func move_one_left()  -> void: await _step_one(Direction.LEFT)
func move_one_right() -> void: await _step_one(Direction.RIGHT)

func _step_one(dir: Direction) -> void:
	facing_dir = dir
	_update_dir_indicator()
	var next : Vector2i = grid_position + _dir_to_offset(dir)
	if _is_blocked(next):
		set_meta("hit_wall_abort", true)
		hit_wall.emit()   # signal main.gd to fail the run
		return
	grid_position   = next
	target_position = grid_to_world(grid_position)
	is_moving       = true
	await _wait_for_arrival()
	if block_manager:
		block_manager.on_robot_enter(grid_position)

# ── Sensing — used by REPEAT-IF-ELSE condition check ──────────────────────────
# Returns true if the given cell is walkable (free), false if blocked.
func sense_cell(cell: Vector2i) -> bool:
	return not _is_blocked(cell)

func reset_to(cell: Vector2i) -> void:
	set_meta("hit_wall_abort", false)
	grid_position   = cell
	position        = grid_to_world(cell)
	target_position = position

# ── Core slide movement (no signal) ───────────────────────────────────────────
func _slide(dir: Direction) -> void:
	if is_moving:
		return
	facing_dir = dir
	_update_dir_indicator()
	var offset : Vector2i = _dir_to_offset(dir)

	while true:
		var next : Vector2i = grid_position + offset
		if _is_blocked(next):
			break
		grid_position   = next
		target_position = grid_to_world(grid_position)
		is_moving       = true
		await _wait_for_arrival()
		if block_manager:
			var done : bool = block_manager.on_robot_enter(grid_position)
			if done:
				action_completed.emit()
				return

func _do_attack() -> void:
	if block_manager:
		var front : Vector2i = grid_position + _dir_to_offset(facing_dir)
		await block_manager.on_robot_attack(front)

func _wait_for_arrival() -> void:
	while is_moving:
		await get_tree().process_frame

func _is_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
		return true
	if block_manager:
		return block_manager.is_blocked(cell)
	return false

func grid_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE

func _dir_to_offset(dir: Direction) -> Vector2i:
	match dir:
		Direction.UP:    return Vector2i( 0, -1)
		Direction.DOWN:  return Vector2i( 0,  1)
		Direction.LEFT:  return Vector2i(-1,  0)
		Direction.RIGHT: return Vector2i( 1,  0)
	return Vector2i.ZERO
