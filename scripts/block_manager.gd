extends Node2D
class_name BlockManager

const TILE_SIZE : int = 88

signal level_complete

var _data          : LevelData   = null
var _coll_hp       : Dictionary  = {}
var _locks_open    : Array[bool] = []
var _total_actions : int         = 0
var _nodes         : Dictionary  = {}

# ── Texture paths ──────────────────────────────────────────────────────────────
const TEX_FLOOR              : String = "res://assets/Blocks/floor.png"         
const TEX_EVEN_INACTIVE     : String = "res://assets/Blocks/even-block-inactive.png"  
const TEX_ODD_INACTIVE      : String = "res://assets/Blocks/odd-block-inactive.png"   
const TEX_EVEN_ACTIVE       : String = "res://assets/Blocks/even-block.png"
const TEX_ODD_ACTIVE        : String = "res://assets/Blocks/odd-block.png"
const TEX_COLLAPSIBLE_INTACT : String = "res://assets/Blocks/collapsible-block.png"
const TEX_COLLAPSIBLE_BROKEN : String = "res://assets/Blocks/collapsible-block-broken.png"
const TEX_BUTTON_OFF         : String = "res://assets/Blocks/lock-switch-off.png"
const TEX_BUTTON_ON          : String = "res://assets/Blocks/lock-switch-on.png"
const TEX_WALL               : String = "res://assets/Blocks/wall.png"
const TEX_LOCK               : String = "res://assets/Blocks/lock-off.png"
const TEX_LOCK_OPEN          : String = "res://assets/Blocks/lock-on.png" 
const TEX_PORTAL             : String = "res://assets/Blocks/door-closed.png"

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
	# ── Floor tiles first so everything else renders on top ────────────────────
	_spawn_floor_layer()                                                         # ← NEW

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

func _make_base_node(cell: Vector2i, node_name: String) -> Node2D:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = node_name
	add_child(c)
	_nodes[cell] = c
	return c

func _add_label(parent: Node, text: String, font_size: int, color: Color, offset: Vector2) -> Label:
	var lbl := Label.new()
	lbl.text     = text
	lbl.position = offset
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	parent.add_child(lbl)
	return lbl

func _add_sprite(parent: Node2D, tex_path: String, node_name: String = "Tex", start_visible: bool = true) -> Sprite2D:
	var s := Sprite2D.new()
	s.name     = node_name
	s.texture  = load(tex_path)
	s.position = Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	var tex_size : Vector2 = s.texture.get_size()
	s.scale    = Vector2(TILE_SIZE / tex_size.x, TILE_SIZE / tex_size.y)
	s.visible  = start_visible
	parent.add_child(s)
	return s

# ── Floor layer ────────────────────────────────────────────────────────────────
# Spawns a static floor tile at every walkable cell:
#   - all floor_cells (plain walkable ground)
#   - beneath even/odd blocks
#   - beneath buttons and locks
# Walls and portal do NOT get a floor tile underneath.
func _spawn_floor_layer() -> void:
	# Auto-compute every walkable cell from grid bounds.
	# Walls and the portal are NOT floored — everything else is.
	var wall_set : Dictionary = {}
	for cell in _data.wall_cells:
		wall_set[cell] = true

	for y in range(6):        # GRID_ROWS
		for x in range(9):    # GRID_COLS
			var cell := Vector2i(x, y)
			if wall_set.has(cell): continue
			if cell == _data.portal_cell: continue
			_spawn_floor_tile(cell)
			
func _spawn_floor_tile(cell: Vector2i) -> void:                                  # ← NEW
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "FLOOR_%d_%d" % [cell.x, cell.y]
	# Floor tiles are NOT stored in _nodes — they're purely visual
	# and never need to be looked up or removed individually
	_add_sprite(c, TEX_FLOOR, "Tex")
	add_child(c)
	move_child(c, 0)   # push to bottom of scene tree so it renders behind everything

# ── Walls ──────────────────────────────────────────────────────────────────────
func _spawn_wall(cell: Vector2i) -> void:
	var c := _make_base_node(cell, "WALL_%d_%d" % [cell.x, cell.y])
	_add_sprite(c, TEX_WALL, "Tex")

# ── Portal ─────────────────────────────────────────────────────────────────────
func _spawn_portal(cell: Vector2i) -> void:
	var c := _make_base_node(cell, "PORTAL_%d_%d" % [cell.x, cell.y])
	_add_sprite(c, TEX_PORTAL, "Tex")
	var lbl := Label.new()
	lbl.text = "EXIT"
	lbl.position = Vector2(TILE_SIZE * 0.18, TILE_SIZE * 0.35)
	GameConfig.apply(lbl, 16)  
	lbl.add_theme_color_override("font_color", Color.WHITE)
	c.add_child(lbl)

func _spawn_collapsible(cell: Vector2i, hp: int) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "COLL_%d_%d" % [cell.x, cell.y]

	var bg := ColorRect.new()
	bg.name  = "BG"
	bg.size  = Vector2(TILE_SIZE, TILE_SIZE)
	bg.color = Color(0.90, 0.90, 0.90, 0.0)
	c.add_child(bg)

	_add_sprite(c, TEX_COLLAPSIBLE_INTACT, "TexIntact", true)
	_add_sprite(c, TEX_COLLAPSIBLE_BROKEN, "TexBroken", false)

	var lbl      := Label.new()
	lbl.name      = "HPLabel"
	lbl.text      = str(hp)
	lbl.position  = Vector2(TILE_SIZE * 0.58, TILE_SIZE * 0.55)
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", Color.WHITE)
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
	bg.color = Color(0.95, 0.95, 0.95, 0.0)
	c.add_child(bg)

	# ── INACTIVE texture (shown when BLOCKED/pathway closed) ─────────────
	var inactive_tex_path : String = TEX_EVEN_ACTIVE if is_even else TEX_ODD_ACTIVE
	var inactive_sprite := _add_sprite(c, inactive_tex_path, "InactiveTexture", true)
	inactive_sprite.modulate.a = 1.0  # ← Semi-transparent when blocking

	# ── ACTIVE texture (shown when OPEN/pathway passable) ─────────────────
	var active_tex_path : String = TEX_EVEN_INACTIVE if is_even else TEX_ODD_INACTIVE
	var active_sprite := _add_sprite(c, active_tex_path, "ActiveSprite", false)
	active_sprite.modulate.a = 0.4    # ← Full opacity when passable

	add_child(c)
	_nodes[cell] = c
	_refresh_eo_visual(cell, is_even, 0)
	
	
func _spawn_button(cell: Vector2i, idx: int) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "BTN_%d" % idx

	_add_sprite(c, TEX_BUTTON_OFF, "TexOff", true)
	_add_sprite(c, TEX_BUTTON_ON,  "TexOn",  false)

	add_child(c)
	_nodes[cell] = c

func _spawn_lock(cell: Vector2i, idx: int) -> void:
	var c := Node2D.new()
	c.position = _cell_pos(cell)
	c.name     = "LOCK_%d" % idx

	# Locked state (visible by default)
	_add_sprite(c, TEX_LOCK, "TexLocked", true)
	
	# Unlocked/Open state (hidden by default) ← ADD THESE 3 LINES
	_add_sprite(c, TEX_LOCK_OPEN, "TexUnlocked", false)

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

func _show_activation_effect(cell: Vector2i, is_even: bool) -> void:
	if not _nodes.has(cell): return
	
	var container : Node2D = _nodes[cell]
	
	# Create flash effect
	var flash := ColorRect.new()
	flash.name = "ActivationFlash"
	flash.size = Vector2(TILE_SIZE, TILE_SIZE)
	flash.color = Color(0.3, 0.9, 0.3, 0.7) if is_even else Color(0.9, 0.3, 0.9, 0.7)
	flash.z_index = 5
	container.add_child(flash)
	
	# Add "EVEN!" or "ODD!" label
	var lbl := Label.new()
	lbl.text = "EVEN!" if is_even else "ODD!"
	lbl.position = Vector2(TILE_SIZE * 0.15, TILE_SIZE * 0.25)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.z_index = 6
	container.add_child(lbl)
	
	# Fade out and remove after 0.5 seconds
	await get_tree().create_timer(0.5).timeout
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.0, 0.3)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.3)
	await tween.finished
	
	flash.queue_free()
	lbl.queue_free()

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
	var hp   : int    = _coll_hp[facing_cell]
	var node : Node2D = _nodes[facing_cell]
	var lbl  : Label  = node.get_node("HPLabel")
	lbl.text           = str(hp)

	var tex_intact = node.get_node_or_null("TexIntact")
	var tex_broken = node.get_node_or_null("TexBroken")
	if tex_intact and tex_broken:
		tex_intact.visible = false
		tex_broken.visible = true

	var bg : ColorRect = node.get_child(0)
	bg.color = Color(1.0, 0.3, 0.3, 0.6)
	await get_tree().create_timer(0.12).timeout
	bg.color = Color(0.90, 0.90, 0.90, 0.0)

	if hp <= 0:
		node.queue_free()
		_nodes.erase(facing_cell)
		_coll_hp.erase(facing_cell)

func _refresh_eo_visual(cell: Vector2i, is_even: bool, total: int) -> void:
	if not _nodes.has(cell): return
	
	# is_open = true means pathway is PASSABLE (block is "inactive" in your terms)
	var is_open   : bool   = (is_even and total % 2 == 0) or (not is_even and total % 2 != 0)
	var container : Node2D = _nodes[cell]
	
	var tex_inactive = container.get_node_or_null("InactiveTexture")
	var tex_active   = container.get_node_or_null("ActiveSprite")
	
	if tex_inactive:
		tex_inactive.visible = not is_open  # Show when BLOCKED (semi-transparent)
	if tex_active:
		tex_active.visible = is_open        # Show when OPEN (full opacity + glow)
		
	
func _activate_button(btn_idx: int) -> void:
	if btn_idx >= _data.lock_cells.size(): return
	_locks_open[btn_idx] = true

	var btn_node : Node2D = _nodes[_data.button_cells[btn_idx]]
	var tex_off = btn_node.get_node_or_null("TexOff")
	var tex_on  = btn_node.get_node_or_null("TexOn")
	if tex_off: tex_off.visible = false
	if tex_on:  tex_on.visible  = true

	var lock_cell : Vector2i = _data.lock_cells[btn_idx]
	if _nodes.has(lock_cell):
		var lock_node : Node2D = _nodes[lock_cell]
		var tex_locked   = lock_node.get_node_or_null("TexLocked")    # ← ADD THESE 4 LINES
		var tex_unlocked = lock_node.get_node_or_null("TexUnlocked")
		if tex_locked:   tex_locked.visible   = false
		if tex_unlocked: tex_unlocked.visible = true
		# ← REMOVED: .queue_free() and .erase() so the open lock stays visible
