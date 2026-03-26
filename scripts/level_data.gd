extends Resource
class_name LevelData

# ── Basic level info ───────────────────────────────────────────────────────────
@export var level_name    : String  = "Level"
@export var action_limit  : int     = 8
@export var player_start  : Vector2i = Vector2i(0, 5)
@export var next_level_scene : String = ""

# ── Which commands appear in the palette for this level ────────────────────────
# Valid strings: "up", "down", "left", "right", "attack", "loop", "append"
# Leave empty to show all standard commands.
@export var available_commands : Array[String] = [
	"up", "down", "left", "right", "attack", "loop", "append"
]

# ── Grid data ──────────────────────────────────────────────────────────────────
@export var wall_cells        : Array[Vector2i] = []
@export var portal_cell       : Vector2i        = Vector2i(-1, -1)
@export var collapsible_cells : Array[Vector2i] = []
@export var collapsible_hp    : Array[int]       = []
@export var even_cells        : Array[Vector2i] = []
@export var odd_cells         : Array[Vector2i] = []
@export var button_cells      : Array[Vector2i] = []
@export var lock_cells        : Array[Vector2i] = []
@export var floor_cells : Array[Vector2i] = []

# ── IF-ELSE mode ───────────────────────────────────────────────────────────────
# When true:
#   • The standard command palette is hidden (no basic move buttons)
#   • The workspace is replaced by the blueprint widget
#   • action_limit is ignored (no move counter shown)
#   • Per-cell movement is used (robot moves 1 tile at a time)
@export var use_if_else_mode  : bool = false

# ── Blueprint definition ───────────────────────────────────────────────────────
# Array of Dictionaries, one per REPEAT-IF-ELSE block in the template.
# Each dict has these keys:
#
#   "repeat_count"    : int     — number of iterations (always fixed, shown as label)
#   "check_direction" : Variant — String ("UP"/"DOWN"/"LEFT"/"RIGHT") or null (dropdown)
#   "check_condition" : Variant — String ("is_free"/"is_obstacle") or null (dropdown)
#   "then_action"     : Variant — String ("move_up"/"move_down"/etc) or null (dropdown)
#   "else_action"     : Variant — String ("move_up"/"move_down"/etc) or null (dropdown)
#
# "?"   = player must choose via dropdown (blank slot)
#         Use "?" in .tres files — Godot cannot store null inside Dictionaries.
# String = pre-filled, displayed as read-only text (e.g. "LEFT", "is_free", "move_up")

# Blueprints are defined in main.gd BLUEPRINTS dict, keyed by level_name.
# Godot cannot serialize nested Dicts in .tres — blueprints live in code.
