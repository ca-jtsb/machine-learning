extends Resource
class_name LevelData

## One .tres file per level. Fill in the Inspector or in code.
## ----------------------------------------------------------------
## HOW TO CREATE A NEW LEVEL:
##   1. FileSystem → right-click res://levels/ → New Resource
##   2. Pick "LevelData" from the list → save as level_1.tres etc.
##   3. Fill the arrays in the Inspector (see field descriptions below)
## ----------------------------------------------------------------

# Level meta
@export var level_name   : String  = "Level 1"
@export var action_limit : int     = 8

# Player start cell (col, row)  col 0-8 / row 0-5
@export var player_start : Vector2i = Vector2i(0, 5)

# Scene to load when the portal is reached. Leave blank for "you win" screen.
@export var next_level_scene : String = ""   # e.g. "res://scenes/level_2.tscn"

# ── Block cells ───────────────────────────────────────────────────────────────
# Black walls — impassable, stop all movement
@export var wall_cells : Array[Vector2i] = []

# Green portal — stepping on it completes the level
@export var portal_cell : Vector2i = Vector2i(-1, -1)  # -1,-1 = none

# White cracked blocks — need ATTACK commands to break
# collapsible_cells[i] and collapsible_hp[i] must be the same length
@export var collapsible_cells : Array[Vector2i] = []
@export var collapsible_hp    : Array[int]       = []

# White Even blocks — passable when total actions taken is even (0, 2, 4…)
@export var even_cells : Array[Vector2i] = []

# White Odd blocks — passable when total actions taken is odd (1, 3, 5…)
@export var odd_cells : Array[Vector2i] = []

# Buttons + Locks — button[i] unlocks lock[i]; arrays must be same length
@export var button_cells : Array[Vector2i] = []
@export var lock_cells   : Array[Vector2i] = []
