extends Node2D
class_name BlockManager

const TILE_SIZE : int = 80   # must match GridDrawer and Robot

signal level_complete

var _data          : LevelData   = null
var _coll_hp       : Dictionary  = {}
var _locks_open    : Array[bool] = []
var _total_actions : int         = 0
var _nodes         : Dictionary  = {}

func load_level(data: LevelData) -> void:
	_clear_all()
	_data          = data
	_total_actions = 0
	_locks_open.clear()
	_locks_open.resize(data.lock_cells.size())
	_locks_open.fill(false)
	_spawn_all()

func _clear_all() -> void:
	for child in get_children():
		child.queue_free()
	_nodes.clear()
	_coll_hp.clear()

func _spawn_all() -> void:
	for cell in _data.wall_cells:
		_spawn_wall(cell)
	if _data.portal_cell.x >= 0:
		_spawn_portal(_data.portal_cell)
	for i in _data.collapsible_cells.size():
		var hp : int = _data.collapsible_hp[i] if i < _data.collapsible_hp.size() else 3
		_spawn_collapsible(_data.collapsible_cells[i], hp)
	for cell in _data.even_cells:
		_spawn_even_odd(cell, true)
	for cell in _data.odd_cells:
		_spawn_even_odd(cell, false)
	for i in _data.button_cells.size():
		_spawn_button(_data.button_cells[i], i)
	for i in _data.lock_cells.size():
		_spawn_lock(_data.lock_cells[i], i)

func _cell_pos(cell: Vector2i) -> Vector2:
	return Vector2(cell) * TILE_SIZE

func _make_base_rect(cell: Vector2i, color: Color, node_name: String) -> ColorRect:
	var r := ColorRect.new()
	r.position = _cell_pos(cell)
	r.size     = Vector2(TILE_SIZE, TILE_SIZE)
	r.color    = color
	r.name     = node_name
	add_child(r)
	_nodes[cell] = r
	return r

func _add_label(parent: Node, text: String, font_size: int, color: Color, offset: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = offset
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

func _spawn_wall(cell: Vector2i) -> void:
	_make_base_rect(cell, Color(0.05, 0.05, 0.05), "WALL_%d_%d" % [cell.x, cell.y])

func _spawn_portal(cell: Vector2i) -> void:
	var r := _make_base_rect(cell, Color(0.08, 0.60, 0.18), "PORTAL_%d_%d" % [cell.x, cell.y])
	_add_label(r, "EXIT", 16, Color.WHITE, Vector2(TILE_SIZE * 0.18, TILE_SIZE * 0.35))

func _spawn_collapsible(cell: Vector2i, hp: int) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "COLL_%d_%d" % [cell.x, cell.y]
	var bg := ColorRect.new()
	bg.size  = Vector2(TILE_SIZE, TILE_SIZE)
	bg.color = Color(0.90, 0.90, 0.90)
	c.add_child(bg)
	var lbl           := Label.new()
	lbl.name           = "HPLabel"
	lbl.text           = str(hp)
	lbl.position       = Vector2(TILE_SIZE * 0.33, TILE_SIZE * 0.15)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	c.add_child(lbl)
	add_child(c)
	_nodes[cell]   = c
	_coll_hp[cell] = hp

func _spawn_even_odd(cell: Vector2i, is_even: bool) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "%s_%d_%d" % [("EVEN" if is_even else "ODD"), cell.x, cell.y]
	var bg := ColorRect.new()
	bg.name  = "Rect"
	bg.size  = Vector2(TILE_SIZE, TILE_SIZE)
	bg.color = Color(0.95, 0.95, 0.95)
	c.add_child(bg)
	var lbl           := Label.new()
	lbl.name           = "Label"
	lbl.text           = "Even" if is_even else "Odd"
	lbl.position       = Vector2(TILE_SIZE * 0.12, TILE_SIZE * 0.3)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	c.add_child(lbl)
	add_child(c)
	_nodes[cell] = c
	_refresh_eo_visual(cell, is_even, 0)

func _spawn_button(cell: Vector2i, idx: int) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "BTN_%d" % idx
	var bg := ColorRect.new()
	bg.name  = "Rect"
	bg.size  = Vector2(TILE_SIZE, TILE_SIZE)
	bg.color = Color(0.75, 0.08, 0.08)
	c.add_child(bg)
	var lbl           := Label.new()
	lbl.text           = "BTN"
	lbl.position       = Vector2(TILE_SIZE * 0.18, TILE_SIZE * 0.35)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	c.add_child(lbl)
	add_child(c)
	_nodes[cell] = c

func _spawn_lock(cell: Vector2i, idx: int) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "LOCK_%d" % idx
	var bg := ColorRect.new()
	bg.name  = "Rect"
	bg.size  = Vector2(TILE_SIZE, TILE_SIZE)
	bg.color = Color(0.80, 0.70, 0.10)
	c.add_child(bg)
	var lbl           := Label.new()
	lbl.text           = "LOCK"
	lbl.position       = Vector2(TILE_SIZE * 0.12, TILE_SIZE * 0.35)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	c.add_child(lbl)
	add_child(c)
	_nodes[cell] = c

# ── Public API ─────────────────────────────────────────────────────────────────
func is_blocked(cell: Vector2i) -> bool:
	if _data == null: return false
	if _data.wall_cells.has(cell): return true
	if _coll_hp.has(cell): return true
	var lock_idx : int = _data.lock_cells.find(cell)
	if lock_idx != -1 and not _locks_open[lock_idx]: return true
	if _data.even_cells.has(cell) and _total_actions % 2 != 0: return true
	if _data.odd_cells.has(cell)  and _total_actions % 2 == 0: return true
	return false

func on_robot_enter(cell: Vector2i) -> bool:
	if _data == null: return false
	if _data.portal_cell == cell:
		emit_signal("level_complete")
		return true
	var btn_idx : int = _data.button_cells.find(cell)
	if btn_idx != -1:
		_activate_button(btn_idx)
	return false

func on_action_taken(total: int) -> void:
	_total_actions = total
	for cell in _data.even_cells: _refresh_eo_visual(cell, true,  total)
	for cell in _data.odd_cells:  _refresh_eo_visual(cell, false, total)

func on_robot_attack(facing_cell: Vector2i) -> void:
	if not _coll_hp.has(facing_cell): return
	_coll_hp[facing_cell] -= 1
	var hp   : int      = _coll_hp[facing_cell]
	var node : Node2D   = _nodes[facing_cell]
	var lbl  : Label    = node.get_node("HPLabel")
	lbl.text             = str(hp)
	var bg   : ColorRect = node.get_child(0)
	bg.color = Color(1.0, 0.3, 0.3)
	await get_tree().create_timer(0.12).timeout
	bg.color = Color(0.90, 0.90, 0.90)
	if hp <= 0:
		node.queue_free()
		_nodes.erase(facing_cell)
		_coll_hp.erase(facing_cell)

func _refresh_eo_visual(cell: Vector2i, is_even: bool, total: int) -> void:
	if not _nodes.has(cell): return
	var open      : bool      = (is_even and total % 2 == 0) or (not is_even and total % 2 != 0)
	var container : Node2D    = _nodes[cell]
	var rect      : ColorRect = container.get_node("Rect")
	var lbl       : Label     = container.get_node("Label")
	rect.color   = Color(0.95, 0.95, 0.95, 0.20 if open else 1.0)
	lbl.modulate = Color(1, 1, 1, 0.25 if open else 1.0)

func _activate_button(btn_idx: int) -> void:
	if btn_idx >= _data.lock_cells.size(): return
	_locks_open[btn_idx] = true
	var btn_node : Node2D   = _nodes[_data.button_cells[btn_idx]]
	(btn_node.get_node("Rect") as ColorRect).color = Color(0.1, 0.65, 0.1)
	var lock_cell : Vector2i = _data.lock_cells[btn_idx]
	if _nodes.has(lock_cell):
		_nodes[lock_cell].queue_free()
		_nodes.erase(lock_cell)
