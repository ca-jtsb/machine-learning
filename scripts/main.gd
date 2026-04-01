extends Node2D

const TutorialOverlay     = preload("res://scenes/tutorial_overlay.tscn")
const LevelCompleteScreen = preload("res://scenes/level_complete.tscn")
const EndingScreen = preload("res://scenes/ending_screen.tscn")

# ── Scene references ───────────────────────────────────────────────────────────
@onready var robot         : Robot         = $GameWorld/Robot
@onready var block_manager : BlockManager  = $GameWorld/BlockManager
@onready var workspace     : VBoxContainer = $UI/WorkspacePanel/Workspace
@onready var run_button    : Button        = $UI/RunButton
@onready var count_label   : Label         = $UI/ActionCounterPanel/VBoxContainer/CountLabel
@onready var title_label   : Label         = $UI/ActionCounterPanel/VBoxContainer/TitleLabel
@onready var btn_backspace : Button        = $UI/BackspaceButton
@onready var help_button   : Button        = $UI/HelpButton

@onready var btn_up     : Button = $UI/CommandPalette/UpButton
@onready var btn_down   : Button = $UI/CommandPalette/DownButton
@onready var btn_left   : Button = $UI/CommandPalette/LeftButton
@onready var btn_right  : Button = $UI/CommandPalette/RightButton
@onready var btn_attack : Button = $UI/CommandPalette/AttackButton
@onready var btn_loop   : Button = $UI/CommandPalette/LoopButton
@onready var btn_append : Button = $UI/CommandPalette/AppendButton

# ── Level list ─────────────────────────────────────────────────────────────────
@export var levels : Array[String] = [
	"res://levels/level_1.tres",
	"res://levels/level_2.tres",
	"res://levels/level_3.tres",
	"res://levels/level_4.tres",
	"res://levels/level_5.tres",
	"res://levels/level_6.tres",
	"res://levels/level_7.tres",
	"res://levels/level_8.tres",
	"res://levels/level_9.tres",
	"res://levels/level_10.tres",
]

var _attempt_counts  : Dictionary = {}   # key: display label → int
var _current_attempt_key : String = "" 

const IF_ELSE_UNLOCK_FROM_LEVEL : int = 0

# ── Blueprint definitions ─────────────────────────────────────────────────────
# "?" = blank dropdown. All other string values are pre-filled (read-only).
# compound_condition / compound_then / compound_else keys enable && in those slots.
const BLUEPRINTS : Dictionary = {
	"Level 7 - The Algorithm": [
		{ "repeat_count": 1,  "check_direction": "?", "check_condition": "?", "then_action": "?", "else_action": "?" },
		{ "repeat_count": 1, "check_direction": "?", "check_condition": "?", "then_action": "?", "else_action": "?" },
	],
	"Level 8": [
		{ "repeat_count": 1, "check_direction": "RIGHT", "check_condition": "is_obstacle", "then_action": "attack", "else_action": "move_right" },
	],

	# ── Level 9: ALL blank — player fills direction, condition, and actions ──────
	"Level 9": [
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
	],

	# ── Level 9 ALT: introduced after solving, shows && condition ──────────────
	"Level 9 - Alt": [
		{
			"repeat_count": 11,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "move_up",
			"else_action": "move_right", "compound_else": true, "else_action2": "attack",
			"else2_attack_dir": "RIGHT"
		},
	],

	# ── Level 10: player fills blank slots ─────────────────────────────────────
	"Level 10": [
		{
			"repeat_count": 7,
			"check_direction": "RIGHT", "check_condition": "is_free",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 8,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"then_action": "attack", "then_attack_dir": "RIGHT",
			"compound_then": true, "then_action2": "move_right",
			"else_action": "move_right"
		},
		{
			"repeat_count": 5,
			"check_direction": "DOWN", "check_condition": "is_free",
			"then_action": "move_down",
			"else_action": "move_left"
		},
	],

	# ── "Final Level" alias — matches level_name in level_10.tres ──────────────
	# If your .tres uses level_name = "Final Level", this entry handles it.
	# If your .tres uses "Level 10", the entry above handles it. Keep both.
	"Final Level": [
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 1,
			"check_direction": "?", "check_condition": "?",
			"then_action": "?",
			"else_action": "?"
		},
	],
	"Final Level - Alt": [
		{
			"repeat_count": 7,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "move_up",
			"else_action": "move_right"
		},
		{
			"repeat_count": 10,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"then_action": "?",
			"else_action": "?"
		},
		{
			"repeat_count": 5,
			"check_direction": "DOWN", "check_condition": "is_free",
			"then_action": "move_down",
			"else_action": "move_left"
		},
	],

	# ── Level 10 ALT ──────────────────────────────────────────────────────────
	# Block 1: && condition teaches optimization — checks RIGHT==obstacle AND UP==free
	# to decide whether to go up (T-junction) or keep going right (corridor).
	# Block 2: attack RIGHT first, then step right — this order works because the
	# robot stays put while attacking, only moving forward once the block is gone.
	# Block 3: same as original — descend and exit.
	"Level 10 - Alt": [
		{
			"repeat_count": 7,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"compound_condition": true, "check_direction2": "UP", "check_condition2": "is_free",
			"then_action": "move_up",
			"else_action": "move_right"
		},
		{
			"repeat_count": 8,
			"check_direction": "RIGHT", "check_condition": "is_obstacle",
			"then_action": "attack", "then_attack_dir": "RIGHT",
			"compound_then": true, "then_action2": "move_right",
			"else_action": "move_right"
		},
		{
			"repeat_count": 5,
			"check_direction": "DOWN", "check_condition": "is_free",
			"then_action": "move_down",
			"else_action": "move_left"
		},
	],
}

# ── Alt-solution config: which levels show alt after solving ───────────────────
# Key = level_name, value = { "hint": text, "alt_key": BLUEPRINTS key to show }
const ALT_SOLUTIONS : Dictionary = {
	"Level 9": {
		# 👇 Now an array of tutorial steps instead of a single string
		"hint": [
			{
				"text": "🎉 Great work! Now let's optimize with [b]&& (AND)[/b] logic.",
				"pointer_pos": null,
			},
			{
				"text": "Instead of two separate blocks, check TWO conditions in one:\n[b]RIGHT == obstacle && UP == free[/b]",
				"pointer_pos": Vector2(800, 90),   # Points at IF condition dropdowns
				"box_position": "near_pointer",
			},
			{
				"text": "If [b]BOTH[/b] are true → robot moves UP.\nIf not → it moves RIGHT.\n\n[b]This reduces your blocks from 2 → 1![/b]",
				"pointer_pos": Vector2(800, 120),   # Points at THEN/ELSE rows
				"box_position": "near_pointer",
			},
			{
				"text": "Try running the program above to see it in action! ▶",
				"pointer_pos": null,   # Center of right blueprint panel
			},
		],
		"alt_key": "Level 9 - Alt"
	},

	"Final Level": {
		"hint": [
			{
				"text": "The level reseted? I think there was a glitch in the system.",
				"pointer_pos": null,
			},
			{
				"text": "It also changed the blueprint for the level...",
				"pointer_pos": null,
			},
			{
				"text": "I guess the solution is more optimized though as it utilizes lesser loop blocks.",
				"pointer_pos": null,
			},
			{
				"text": "But it uses the '&&' conditions just like in the previous level. Just figure out the right commands and you will arrive at the exit.",
				"pointer_pos": Vector2(800, 120),   # Points at THEN/ELSE rows
				"box_position": "near_pointer",
			},
		],
		"alt_key": "Final Level - Alt"
	},
}

# ══════════════════════════════════════════════════════════════════════════════
# PALETTE BUTTON ASSETS — edit here to map textures to each command button.
#
# Each entry: [ key, label, texture_path, hover_color ]
#   key          — matches available_commands strings ("up","down","attack" etc.)
#   label        — fallback text shown if texture is null or file missing
#   texture_path — path to .png asset, or "" to use label-only orange button
#   hover_color  — Color tint applied on hover (slightly lighter than normal)
#
# To assign an asset: set texture_path to e.g. "res://assets/UI/btn_move_up.png"
# To use text-only button: leave texture_path as ""
# ══════════════════════════════════════════════════════════════════════════════
const PALETTE_BUTTONS : Array = [
	# [ key,      label,          texture_path,                  hover_color (fallback only) ]
	# Set texture_path to "res://assets/UI/yourfile.png" to use an icon asset.
	# Leave "" to show a plain orange text button instead.
	[ "up",      "Move Up ↑",    "res://assets/UI/UP.png",      Color(0.1333, 0.9294, 0.1725, 1.0) ],
	[ "down",    "Move Down ↓",  "res://assets/UI/DOWN.png",    Color(0.1333, 0.9294, 0.1725, 1.0) ],
	[ "left",    "Move Left ←",  "res://assets/UI/LEFT.png",    Color(0.1333, 0.9294, 0.1725, 1.0) ],
	[ "right",   "Move Right →", "res://assets/UI/RIGHT.png",   Color(0.1333, 0.9294, 0.1725, 1.0) ],
	[ "attack",  "⚔ ATTACK",     "res://assets/UI/ATTACK.png",                            Color(0.1333, 0.9294, 0.1725, 1.0) ],
	[ "loop",    "↺ LOOP",       "res://assets/UI/LOOP.png",                            Color(0.1333, 0.9294, 0.1725, 1.0) ],
	[ "append",  "&& APPEND",    "res://assets/UI/APPEND.png",                            Color(0.1333, 0.9294, 0.1725, 1.0) ],
]

# ── State ──────────────────────────────────────────────────────────────────────
var current_level_index   : int  = 0
var command_blocks        : Array[CommandBlock] = []
var is_executing          : bool = false
var current_command_index : int  = 0
var total_actions_taken   : int  = 0
var max_actions           : int  = 8
var _level_complete       : bool = false
var _is_if_else_mode      : bool = false
var _tutorial_seen        : Array[bool] = []
var _current_level_name   : String = ""
var _showing_alt          : bool   = false   # suppresses level_complete popup during alt demo
var _hit_wall             : bool   = false   # set true when robot walks into wall in Phase 2 → triggers failure

# ── IF-ELSE blueprint widgets ──────────────────────────────────────────────────
var _if_else_blocks    : Array            = []
var _if_else_workspace : VBoxContainer   = null
var _if_else_scroll    : ScrollContainer = null
var _if_else_panel     : PanelContainer  = null

# Phase 1 UI — built once, shown only in standard mode
var _std_panel         : PanelContainer  = null   # right panel showing placed commands
var _std_workspace     : VBoxContainer   = null   # VBox inside right panel
var _bottom_palette    : PanelContainer  = null   # bottom orange command button panel

# ── Pending modifier state ─────────────────────────────────────────────────────
enum PendingMode { NONE, LOOP, APPEND_FIRST, APPEND_SECOND }
var _pending_mode         : PendingMode = PendingMode.NONE
var _pending_first_action : CommandBlock.CommandType = CommandBlock.CommandType.MOVE_UP
var _pending_loop_count   : int = 3

# ── Help panel ─────────────────────────────────────────────────────────────────
var _help_panel  : PanelContainer = null
var _help_button : Button         = null

# ── Layout constants ───────────────────────────────────────────────────────────
const GRID_X_STANDARD    : float = 16.0    # grid starts at x=16 in both modes now
const GRID_X_IF_ELSE     : float = 16.0
const GRID_Y             : float = 8.0
# Phase 1 right command panel (placed commands) — same geometry as Phase 2 blueprint panel
const STD_PANEL_X        : float = 816.0
const STD_PANEL_RIGHT    : float = 1146.0
const STD_PANEL_TOP      : float = 8.0
const STD_PANEL_BOTTOM   : float = -112.0
# Phase 2 blueprint panel — same values, kept separate for clarity
const IFELSE_PANEL_X     : float = 816.0
const IFELSE_PANEL_RIGHT : float = 1146.0
const IFELSE_PANEL_TOP   : float = 8.0
const IFELSE_PANEL_BOTTOM : float = -112.0
# Bottom command palette panel (Phase 1 only)
const BOTTOM_PALETTE_TOP : float = 536.0   # grid_y(8) + grid_h(528) = 536

# ══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	var spr = robot.get_node_or_null("Sprite2D")
	if spr: spr.queue_free()

	btn_up.pressed.connect(func():     _on_basic_pressed(CommandBlock.CommandType.MOVE_UP))
	btn_down.pressed.connect(func():   _on_basic_pressed(CommandBlock.CommandType.MOVE_DOWN))
	btn_left.pressed.connect(func():   _on_basic_pressed(CommandBlock.CommandType.MOVE_LEFT))
	btn_right.pressed.connect(func():  _on_basic_pressed(CommandBlock.CommandType.MOVE_RIGHT))
	btn_attack.pressed.connect(func(): _on_basic_pressed(CommandBlock.CommandType.ATTACK))
	btn_loop.pressed.connect(_on_loop_pressed)
	btn_append.pressed.connect(_on_append_pressed)
	run_button.pressed.connect(_on_run_pressed)
	help_button.pressed.connect(_on_help_pressed)
	btn_backspace.pressed.connect(_remove_last_cmd)
	robot.action_completed.connect(_on_action_completed)
	robot.hit_wall.connect(_on_hit_wall)
	block_manager.level_complete.connect(_on_level_complete)
	robot.block_manager = block_manager

	_tutorial_seen.resize(levels.size())
	_tutorial_seen.fill(false)

	_build_help_ui()
	_build_if_else_workspace()
	_build_standard_ui()
	_load_level(current_level_index)

# ── IF-ELSE right-side panel ───────────────────────────────────────────────────
func _build_if_else_workspace() -> void:
	var ui_layer = $UI
	var panel := PanelContainer.new()
	panel.name          = "IfElsePanel"
	panel.anchor_left   = 0.0; panel.anchor_right  = 0.0
	panel.anchor_top    = 0.0; panel.anchor_bottom = 1.0
	panel.offset_left   = IFELSE_PANEL_X
	panel.offset_right  = IFELSE_PANEL_RIGHT
	panel.offset_top    = IFELSE_PANEL_TOP
	panel.offset_bottom = IFELSE_PANEL_BOTTOM
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.08, 0.08, 0.12, 1.0)
	style.border_color = Color("#00A7D1")
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 2)
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	ui_layer.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 8)
	panel.add_child(margin)

	_if_else_scroll = ScrollContainer.new()
	_if_else_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_if_else_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	margin.add_child(_if_else_scroll)

	_if_else_workspace = VBoxContainer.new()
	_if_else_workspace.add_theme_constant_override("separation", 12)
	_if_else_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_if_else_scroll.add_child(_if_else_workspace)

	_if_else_panel = panel

# ── Phase 1 UI — right command panel + bottom palette ─────────────────────────
func _build_standard_ui() -> void:
	var ui_layer = $UI

	# ── Right command panel (shows placed command blocks vertically) ──────────
	_std_panel = PanelContainer.new()
	_std_panel.name          = "StdPanel"
	_std_panel.anchor_left   = 0.0; _std_panel.anchor_right  = 0.0
	_std_panel.anchor_top    = 0.0; _std_panel.anchor_bottom = 1.0
	_std_panel.offset_left   = STD_PANEL_X
	_std_panel.offset_right  = STD_PANEL_RIGHT
	_std_panel.offset_top    = STD_PANEL_TOP
	_std_panel.offset_bottom = STD_PANEL_BOTTOM
	_std_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var std_style := StyleBoxFlat.new()
	std_style.bg_color     = Color(0.08, 0.08, 0.12, 1.0)
	std_style.border_color = Color("#00A7D1")
	for side in ["left","right","top","bottom"]:
		std_style.set("border_width_" + side, 2)
	_std_panel.add_theme_stylebox_override("panel", std_style)
	_std_panel.visible = false
	ui_layer.add_child(_std_panel)

	var std_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		std_margin.add_theme_constant_override("margin_" + side, 8)
	_std_panel.add_child(std_margin)

	var std_scroll := ScrollContainer.new()
	std_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	std_scroll.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	std_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	std_margin.add_child(std_scroll)

	_std_workspace = VBoxContainer.new()
	_std_workspace.add_theme_constant_override("separation", 4)
	_std_workspace.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	std_scroll.add_child(_std_workspace)

	# ── Bottom command palette panel ─────────────────────────────────────────
	_bottom_palette = PanelContainer.new()
	_bottom_palette.name          = "BottomPalette"
	_bottom_palette.anchor_left   = 0.0; _bottom_palette.anchor_right  = 1.0
	_bottom_palette.anchor_top    = 1.0; _bottom_palette.anchor_bottom = 1.0
	_bottom_palette.offset_left   = 0.0; _bottom_palette.offset_right  = -336.0
	_bottom_palette.offset_top    = -112.0; _bottom_palette.offset_bottom = 0.0
	# Leave room at the very bottom for run/backspace buttons
	_bottom_palette.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_bottom_palette.grow_vertical   = Control.GROW_DIRECTION_BEGIN
	var bp_style := StyleBoxFlat.new()
	bp_style.bg_color = Color(0.10, 0.25, 0.45, 1.0)   # blue tint like screenshot
	for side in ["left","right","top","bottom"]:
		bp_style.set("border_width_" + side, 2)
	bp_style.border_color = Color(0.3, 0.6, 1.0, 1.0)
	_bottom_palette.add_theme_stylebox_override("panel", bp_style)
	_bottom_palette.visible = false
	ui_layer.add_child(_bottom_palette)

	var bp_margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		bp_margin.add_theme_constant_override("margin_" + side, 6)
	_bottom_palette.add_child(bp_margin)

	var bp_hbox := HBoxContainer.new()
	bp_hbox.add_theme_constant_override("separation", 8)
	bp_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	bp_margin.add_child(bp_hbox)

	# Store hbox so _refresh_palette can rebuild buttons into it
	_bottom_palette.set_meta("buttons_hbox", bp_hbox)

# ── Help UI ────────────────────────────────────────────────────────────────────
# This must be at the TOP level of the script, NOT inside _build_help_ui()
func _make_help_row(entry: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var tex_rect := TextureRect.new()
	tex_rect.custom_minimum_size = Vector2(36, 36)
	tex_rect.size                = Vector2(36, 36)
	tex_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.clip_contents       = true
	if ResourceLoader.exists(entry[0]):
		tex_rect.texture = load(entry[0])
	row.add_child(tex_rect)

	var text_col := VBoxContainer.new()
	text_col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = entry[1]
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	text_col.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = entry[2]
	desc_lbl.add_theme_font_size_override("font_size", 10)
	desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	text_col.add_child(desc_lbl)

	return row
	
func _build_help_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name  = "HelpCanvas"
	canvas.layer = 100
	add_child(canvas)

	var overlay := ColorRect.new()
	overlay.name         = "HelpOverlay"
	overlay.color        = Color(0, 0, 0, 0.55)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible      = false
	canvas.add_child(overlay)

	_help_panel = PanelContainer.new()
	_help_panel.anchor_left   = 0.5
	_help_panel.anchor_right  = 0.5
	_help_panel.anchor_top    = 0.5
	_help_panel.anchor_bottom = 0.5
	_help_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_help_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color               = Color(0.10, 0.10, 0.16, 1.0)
	style.border_width_left      = 2
	style.border_width_right     = 2
	style.border_width_top       = 2
	style.border_width_bottom    = 2
	style.border_color           = Color(0.30, 0.60, 0.90, 1.0)
	style.corner_radius_top_left     = 12
	style.corner_radius_top_right    = 12
	style.corner_radius_bottom_left  = 12
	style.corner_radius_bottom_right = 12
	_help_panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(_help_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    16)
	margin.add_theme_constant_override("margin_bottom", 16)
	_help_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	# Two column layout
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	vbox.add_child(columns)

	# ── Left column — moves ───────────────────────────────────────────────────
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 8)
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left_col)

	var left_title := Label.new()
	left_title.text = "COMMANDS"
	left_title.add_theme_font_size_override("font_size", 12)
	left_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	left_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_col.add_child(left_title)

	left_col.add_child(HSeparator.new())

	var move_entries : Array = [
		["res://assets/UI/UP.png",     "Move Up",    "Slide upward."],
		["res://assets/UI/DOWN.png",   "Move Down",  "Slide downward."],
		["res://assets/UI/LEFT.png",   "Move Left",  "Slide left."],
		["res://assets/UI/RIGHT.png",  "Move Right", "Slide right."],
		["res://assets/UI/ATTACK.png", "Attack",     "Break block in front."],
		["res://assets/UI/LOOP.png",   "Loop",       "Repeat N times."],
		["res://assets/UI/APPEND.png", "Append",     "Chain two actions."],
	]

	for entry in move_entries:
		left_col.add_child(_make_help_row(entry))

	# ── Divider ───────────────────────────────────────────────────────────────
	var divider := VSeparator.new()
	columns.add_child(divider)

	# ── Right column — block types ────────────────────────────────────────────
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 8)
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right_col)

	var right_title := Label.new()
	right_title.text = "BLOCK TYPES"
	right_title.add_theme_font_size_override("font_size", 12)
	right_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	right_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(right_title)

	right_col.add_child(HSeparator.new())

	var block_entries : Array = [
		["res://assets/Blocks/collapsible-block.png", "Box",  		  "Break it with ATTACK."],
		["res://assets/Blocks/even-block.png",        "Even Block",   "Open on even actions."],
		["res://assets/Blocks/odd-block.png",         "Odd Block",    "Open on odd actions."],
		["res://assets/Blocks/lock-switch-off.png",   "Switch",       "Step on to open lock."],
		["res://assets/Blocks/lock-off.png",    	  "Lock",         "Opens when switch hit."],
	]

	for entry in block_entries:
		right_col.add_child(_make_help_row(entry))

	vbox.add_child(HSeparator.new())

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(100, 32)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.pressed.connect(func(): overlay.visible = false)
	var center := CenterContainer.new()
	center.add_child(close_btn)
	vbox.add_child(center)
	
	

func _on_help_pressed() -> void:
	var canvas = get_node_or_null("HelpCanvas")
	if canvas:
		var overlay = canvas.get_node_or_null("HelpOverlay")
		if overlay:
			overlay.visible = not overlay.visible

# ── Level loading ──────────────────────────────────────────────────────────────
func _load_level(index: int) -> void:
	if index >= levels.size():
		_show_win_screen(); return

	var data : LevelData = load(levels[index]) as LevelData
	if data == null:
		push_error("Could not load: " + levels[index]); return

	max_actions            = data.action_limit
	_level_complete        = false
	_current_level_name    = data.level_name
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	_clear_commands()
	_pending_mode         = PendingMode.NONE
	total_actions_taken   = 0
	current_command_index = 0
	is_executing          = false
	run_button.disabled   = false
	if title_label: title_label.text = data.level_name
	_clear_palette_hint()

	# ── Set attempt key for this level ────────────────────────────────────────
	_current_attempt_key = data.level_name
	if not _attempt_counts.has(_current_attempt_key):
		_attempt_counts[_current_attempt_key] = 0

	var unlock_ok : bool = (index >= IF_ELSE_UNLOCK_FROM_LEVEL)
	_is_if_else_mode = data.use_if_else_mode and unlock_ok

	if _is_if_else_mode:
		_enter_if_else_mode(data)
	else:
		_enter_standard_mode(data)

	_update_counter()

	if index < _tutorial_seen.size() and not _tutorial_seen[index]:
		_tutorial_seen[index] = true
		_show_tutorial(index)
		
func _reload_current_level() -> void:
	_load_level(current_level_index)

# ── Standard mode ──────────────────────────────────────────────────────────────
func _enter_standard_mode(data: LevelData) -> void:
	# Hide all legacy scene panels
	$UI/CommandPalette.visible     = false
	$UI/WorkspacePanel.visible     = false
	workspace.visible              = false
	if _if_else_panel: _if_else_panel.visible = false

	# Show Phase 1 new elements
	if _std_panel:      _std_panel.visible      = true
	if _bottom_palette: _bottom_palette.visible = true
	$UI/BackspaceButton.visible    = false
	$UI/RunButton.visible          = true
	$UI/ActionCounterPanel.visible = true
	
	# Restore standard layout
	if count_label:
		count_label.visible = true
	
	if title_label:
		title_label.visible = true
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		title_label.add_theme_font_size_override("font_size", 14)
	
	# ⭐ Reset VBox alignment for standard mode
	var vbox = $UI/ActionCounterPanel/VBoxContainer
	if vbox:
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		vbox.add_theme_constant_override("separation", 4)

	$GameWorld.position = Vector2(GRID_X_STANDARD, GRID_Y)
	_refresh_palette(data.available_commands)
	
# ── IF-ELSE mode ───────────────────────────────────────────────────────────────
func _enter_if_else_mode(data: LevelData) -> void:
	# Hide Phase 1 elements
	$UI/CommandPalette.visible     = false
	$UI/WorkspacePanel.visible     = false
	if _std_panel:      _std_panel.visible      = false
	if _bottom_palette: _bottom_palette.visible = false

	# Show Phase 2 elements
	$UI/BackspaceButton.visible    = false
	$UI/RunButton.visible          = true
	$UI/ActionCounterPanel.visible = true
	
	# ⭐ Keep count_label space but hide it
	if count_label:
		count_label.modulate = Color(1, 1, 1, 0)
	
	if title_label:
		title_label.visible = true
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# ⭐ Center in the VBoxContainer
	var vbox = $UI/ActionCounterPanel/VBoxContainer
	if vbox:
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 0)

	if _if_else_panel: _if_else_panel.visible = true

	$GameWorld.position = Vector2(GRID_X_IF_ELSE, GRID_Y)
	_populate_blueprint(data.level_name)
	
func _populate_blueprint(level_name: String) -> void:
	for child in _if_else_workspace.get_children():
		child.queue_free()
	_if_else_blocks.clear()

	var blueprint : Array = BLUEPRINTS.get(level_name, [])
	if blueprint.is_empty():
		var placeholder := Label.new()
		placeholder.text = "No blueprint for: " + level_name
		placeholder.add_theme_color_override("font_color", Color.YELLOW)
		_if_else_workspace.add_child(placeholder)
		return

	for block_def in blueprint:
		var widget : RepeatIfElseBlock = _make_widget_from_def(block_def)
		_if_else_workspace.add_child(widget)
		_if_else_blocks.append(widget)

func _make_widget_from_def(block_def: Dictionary) -> RepeatIfElseBlock:
	var w : RepeatIfElseBlock = RepeatIfElseBlock.new()
	w.repeat_count    = block_def.get("repeat_count", 6)
	w.check_direction = _bval(block_def.get("check_direction", "?"))
	w.check_condition = _bval(block_def.get("check_condition", "?"))
	w.use_compound_condition = block_def.get("compound_condition", false)
	w.check_direction2 = _bval(block_def.get("check_direction2", "?"))
	w.check_condition2 = _bval(block_def.get("check_condition2", "?"))
	w.then_action      = _bval(block_def.get("then_action", "?"))
	w.use_compound_then = block_def.get("compound_then", false)
	w.then_action2      = _bval(block_def.get("then_action2", "?"))
	w.else_action      = _bval(block_def.get("else_action", "?"))
	w.use_compound_else = block_def.get("compound_else", false)
	w.else_action2      = _bval(block_def.get("else_action2", "?"))
	# Attack direction overrides — "" means use current facing direction
	w.then_attack_dir  = block_def.get("then_attack_dir",  "")
	w.then2_attack_dir = block_def.get("then2_attack_dir", "")
	w.else_attack_dir  = block_def.get("else_attack_dir",  "")
	w.else2_attack_dir = block_def.get("else2_attack_dir", "")
	return w

func _bval(val: Variant) -> Variant:
	if val == "?": return null
	return val

# ── Execution ──────────────────────────────────────────────────────────────────
func _on_run_pressed() -> void:
	if is_executing: return
	_pending_mode = PendingMode.NONE
	_clear_palette_hint()
	is_executing          = true
	_level_complete       = false
	current_command_index = 0
	total_actions_taken   = 0
	run_button.disabled   = true

	if _is_if_else_mode:
		_hit_wall = false
		_execute_if_else_program()
	else:
		if command_blocks.is_empty():
			is_executing = false; run_button.disabled = false; return
		_execute_next()

func _execute_if_else_program() -> void:
	var cbs : Array[CommandBlock] = []
	for widget in _if_else_blocks:
		if widget is RepeatIfElseBlock:
			cbs.append(widget.build_command_block())

	if cbs.is_empty():
		is_executing = false; run_button.disabled = false; return

	robot.set_meta("level_done", false)

	for cb in cbs:
		if _level_complete or _hit_wall: break
		await cb.execute(robot)
		if _hit_wall: break
		await get_tree().create_timer(0.2).timeout

	for cb in cbs: cb.queue_free()

	if _hit_wall:
		_on_hit_wall_failure()
	elif not _level_complete:
		_on_program_finished_if_else()
	else:
		is_executing = false

func _on_hit_wall_failure() -> void:
	# Overlay was already shown by _on_hit_wall — nothing to do here.
	# The retry button in the overlay handles the reset.
	pass

func _on_program_finished_if_else() -> void:
	_attempt_counts[_current_attempt_key] = _attempt_counts.get(_current_attempt_key, 0) + 1
	is_executing = false
	_show_failure_flash()
	await get_tree().create_timer(1.0).timeout
	var data : LevelData = load(levels[current_level_index]) as LevelData
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	total_actions_taken   = 0
	current_command_index = 0
	run_button.disabled   = false
	robot.set_meta("level_done", false)
	
func _execute_next() -> void:
	if current_command_index >= command_blocks.size():
		_on_program_finished(); return
	
	var cmd : CommandBlock = command_blocks[current_command_index]
	
	# ⭐ OLD: _highlight(cmd)
	# ⭐ NEW: Use the block's built-in highlight
	cmd.set_highlighted(true)
	
	total_actions_taken += 1
	block_manager.on_action_taken(total_actions_taken)
	current_command_index += 1
	
	await cmd.execute(robot)
	
	# ⭐ Turn off highlight after execution
	cmd.set_highlighted(false)
	
	if not is_executing: return
	await get_tree().create_timer(0.15).timeout
	_execute_next()
	
func _on_action_completed() -> void:
	pass

func _on_hit_wall() -> void:
	# Only matters during Phase 2 execution
	if not _is_if_else_mode: return
	if not is_executing: return
	if _hit_wall: return   # already handling it
	_hit_wall    = true
	is_executing = false
	run_button.disabled = true
	# Show overlay immediately — don't wait for the loop to finish
	_show_wall_hit_overlay()

func _show_wall_hit_overlay() -> void:
	var dim := ColorRect.new()
	dim.name = "WallHitDim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "WallHitPanel"
	panel.anchor_left   = 0.5; panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left   = -260.0; panel.offset_right  = 260.0
	panel.offset_top    = -100.0; panel.offset_bottom = 100.0
	var style := StyleBoxFlat.new()
	style.bg_color     = Color(0.10, 0.06, 0.06, 1.0)
	style.border_color = Color(0.85, 0.15, 0.15, 1.0)
	for side in ["left","right","top","bottom"]:
		style.set("border_width_" + side, 3)
	style.corner_radius_top_left    = 8; style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	$UI.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🚧  Hit a Wall!"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "The robot overshot and hit a wall.\nCount your steps more carefully and try again."
	msg.add_theme_font_size_override("font_size", 15)
	msg.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(msg)

	var retry_btn := Button.new()
	retry_btn.text = "↺  Retry"
	retry_btn.add_theme_font_size_override("font_size", 16)
	retry_btn.custom_minimum_size = Vector2(140, 44)
	retry_btn.pressed.connect(func():
		_attempt_counts[_current_attempt_key] = _attempt_counts.get(_current_attempt_key, 0) + 1
		dim.queue_free()
		panel.queue_free()
		_hit_wall = false
		var data : LevelData = load(levels[current_level_index]) as LevelData
		block_manager.load_level(data)
		robot.reset_to(data.player_start)
		robot.set_meta("level_done", false)
		_level_complete = false
		run_button.disabled = false
	)
	vbox.add_child(retry_btn)
	
func _on_program_finished() -> void:
	if not _level_complete:
		_attempt_counts[_current_attempt_key] = _attempt_counts.get(_current_attempt_key, 0) + 1
	is_executing = false
	_clear_highlights()
	if _level_complete: return
	_show_failure_flash()
	await get_tree().create_timer(1.0).timeout
	var data : LevelData = load(levels[current_level_index]) as LevelData
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	_pending_mode         = PendingMode.NONE
	total_actions_taken   = 0
	current_command_index = 0
	run_button.disabled   = false
	_update_counter()
	_clear_palette_hint()
	for cmd in command_blocks:
		if is_instance_valid(cmd):
			cmd.set_highlighted(false)		
			
# ── Level complete flow ────────────────────────────────────────────────────────
func _on_level_complete() -> void:
	_level_complete     = true
	is_executing        = false
	run_button.disabled = true
	_clear_highlights()
	robot.set_meta("level_done", true)

	# During alt demo: reveal Continue button then reset so player can run again
	if _showing_alt:
		var cont = _if_else_workspace.get_node_or_null("AltContinueBtn")
		if cont: cont.visible = true
		var hint = _if_else_workspace.get_node_or_null("AltHintLabel")
		if hint: hint.visible = false
		await get_tree().create_timer(0.8).timeout
		var data : LevelData = load(levels[current_level_index]) as LevelData
		block_manager.load_level(data)
		robot.reset_to(data.player_start)
		robot.set_meta("level_done", false)
		_level_complete = false
		run_button.disabled = false
		return

	# ⭐ FIRST check for alt solutions (even on final level)
	if ALT_SOLUTIONS.has(_current_level_name):
		_show_alt_solution_flow(_current_level_name)
	else:
		# ⭐ Then check if this is the final level
		var is_final_level : bool = (current_level_index >= levels.size() - 1)
		if is_final_level:
			await get_tree().create_timer(0.5).timeout
			_show_ending_screen()
		else:
			_show_level_complete_popup()
				
# ── Alt-solution flow ──────────────────────────────────────────────────────────
func _show_alt_solution_flow(level_name: String) -> void:
	var alt_info : Dictionary = ALT_SOLUTIONS[level_name]
	var hint_data : Variant   = alt_info["hint"]
	var alt_key   : String    = alt_info["alt_key"]
 
	# ── 1. Load the alt blueprint immediately so it's visible behind the hint ──
	_load_alt_blueprint(alt_key, func():
		_show_level_complete_popup()
	)
 
	# ── 2. Now show the hint overlay on top ────────────────────────────────────
	# on_done is a no-op here because _load_alt_blueprint already wired up
	# the Continue button → _show_level_complete_popup chain.
	_show_assistant_overlay(hint_data, func(): pass)
 
func _show_assistant_overlay(hint_data: Variant, on_done: Callable) -> void:
	var overlay = TutorialOverlay.instantiate()
	$UI.add_child(overlay)
	overlay.tutorial_finished.connect(func(): on_done.call())
 
	var steps : Array[Dictionary] = []
 
	if typeof(hint_data) == TYPE_STRING:
		# Legacy: single hint string → wrap in a 1-step array
		steps.append({"text": hint_data, "pointer_pos": null})
	elif typeof(hint_data) == TYPE_ARRAY:
		# New: array of step dicts — copy element-by-element into the typed array
		for entry in hint_data:
			if typeof(entry) == TYPE_DICTIONARY:
				steps.append(entry)
	else:
		# Fallback safety
		steps.append({"text": "Check the blueprint panel on the right!", "pointer_pos": Vector2(980, 270)})
 
	overlay.setup(steps)
 

func _load_alt_blueprint(alt_key: String, on_done: Callable) -> void:
	_showing_alt = true

	# ⭐ Check if this is the final level's alt solution
	var is_final_alt : bool = (alt_key == "Final Level - Alt" or alt_key == "Level 10 - Alt")

	# ── Set attempt key for the alt solution ──────────────────────────────────
	_current_attempt_key = alt_key
	if not _attempt_counts.has(_current_attempt_key):
		_attempt_counts[_current_attempt_key] = 0

	for child in _if_else_workspace.get_children():
		child.queue_free()
	_if_else_blocks.clear()

	var blueprint : Array = BLUEPRINTS.get(alt_key, [])
	for block_def in blueprint:
		var widget := _make_widget_from_def(block_def)
		_if_else_workspace.add_child(widget)
		_if_else_blocks.append(widget)

	var sep := HSeparator.new()
	sep.name = "AltSeparator"
	_if_else_workspace.add_child(sep)

	var continue_btn := Button.new()
	continue_btn.name    = "AltContinueBtn"
	continue_btn.text    = "▶  Continue to Next Level"
	continue_btn.add_theme_font_size_override("font_size", 15)
	continue_btn.custom_minimum_size = Vector2(0, 44)
	continue_btn.visible = false
	continue_btn.pressed.connect(func():
		_showing_alt = false
		if is_final_alt:
			_show_ending_screen()  # ⭐ Show ending screen for final level alt
		else:
			on_done.call()  # Show level complete popup for other levels
	)
	_if_else_workspace.add_child(continue_btn)

	var hint_lbl := Label.new()
	hint_lbl.name = "AltHintLabel"
	hint_lbl.text = "Run the program above to continue!"
	hint_lbl.add_theme_color_override("font_color", Color("#00A7D1"))
	hint_lbl.add_theme_font_size_override("font_size", 13)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_if_else_workspace.add_child(hint_lbl)

	if _if_else_panel and not _if_else_panel.visible:
		_if_else_panel.visible = true
		$GameWorld.position = Vector2(GRID_X_IF_ELSE, GRID_Y)

	var data : LevelData = load(levels[current_level_index]) as LevelData
	block_manager.load_level(data)
	robot.reset_to(data.player_start)
	robot.set_meta("level_done", false)
	_level_complete = false
	run_button.disabled = false
	
	
func _show_level_complete_popup() -> void:
	var popup = LevelCompleteScreen.instantiate()
	$UI.add_child(popup)
	var attempts : int = _attempt_counts.get(_current_attempt_key, 0) as int
	popup.set_attempts(_current_attempt_key, attempts)
	popup.next_level_pressed.connect(func():
		popup.queue_free()
		current_level_index += 1
		_load_level(current_level_index))
		
func _show_win_screen() -> void:
	print("ALL LEVELS COMPLETE!")

# ── Standard palette handlers ──────────────────────────────────────────────────
func _on_loop_pressed() -> void:
	if is_executing: return
	if _pending_mode == PendingMode.LOOP:
		_pending_mode = PendingMode.NONE
		_clear_palette_hint()
		return
	_show_loop_count_popup()

func _on_append_pressed() -> void:
	if is_executing: return
	if _pending_mode in [PendingMode.APPEND_FIRST, PendingMode.APPEND_SECOND]:
		# Cancel APPEND selection
		_pending_mode = PendingMode.NONE
		_clear_palette_hint()
		return
	_pending_mode = PendingMode.APPEND_FIRST
	_set_palette_hint("Pick FIRST action to append…")

func _on_basic_pressed(cmd_type: CommandBlock.CommandType) -> void:
	if is_executing: return
	match _pending_mode:
		PendingMode.NONE:      _add_basic_cmd(cmd_type)
		PendingMode.LOOP:
			var block := CommandBlock.new(CommandBlock.CommandType.LOOP)
			block.loop_action = cmd_type
			block.loop_count = _pending_loop_count
			_finalise_block(block)
			_pending_mode = PendingMode.NONE  # ← Reset FIRST
			_clear_palette_hint()             # ← Then clear hint (which calls _update_action_button_visuals)
			_pending_loop_count = 3  
		PendingMode.APPEND_FIRST:
			_pending_first_action = cmd_type
			_pending_mode         = PendingMode.APPEND_SECOND
			_set_palette_hint("Pick SECOND action to append…")  
		PendingMode.APPEND_SECOND:
			var block := CommandBlock.new(CommandBlock.CommandType.APPEND)
			block.first_action  = _pending_first_action
			block.second_action = cmd_type
			_finalise_block(block)
			_pending_mode = PendingMode.NONE; _clear_palette_hint()

func _finalise_block(block: CommandBlock) -> void:
	if command_blocks.size() >= max_actions:
		block.queue_free(); _flash_error(); return

	var row := _make_cmd_row(block)
	if _std_workspace:
		_std_workspace.add_child(row)
	else:
		workspace.add_child(block)   # fallback for edge cases

	command_blocks.append(block)
	_renumber_rows()
	_update_counter()

# ── Build a numbered + draggable row wrapping one CommandBlock ─────────────────
func _make_cmd_row(block: CommandBlock) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "CmdRow"
	row.add_theme_constant_override("separation", 0)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Line number label
	var num_lbl := Label.new()
	num_lbl.name               = "LineNum"
	num_lbl.custom_minimum_size = Vector2(32, 44)
	num_lbl.add_theme_font_size_override("font_size", 13)
	num_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	num_lbl.text = "1"
	row.add_child(num_lbl)

	# Small gap
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(6, 0)
	row.add_child(gap)

	# The command block itself fills remaining space
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(block)

	# Right-click to remove
	block.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_remove_cmd(block))

	# Drag handle — whole row is draggable for reordering
	_setup_row_drag(row, block)
	return row

# ── Drag-to-reorder ────────────────────────────────────────────────────────────
# ── Drag-to-reorder state ─────────────────────────────────────────────────────
var _drag_row      : HBoxContainer = null
var _drag_pressed  : bool          = false

# _setup_row_drag only marks which row was pressed.
# Actual drag detection happens in _input so mouse motion is tracked globally.
func _setup_row_drag(row: HBoxContainer, _block: CommandBlock) -> void:
	row.gui_input.connect(func(event: InputEvent):
		if is_executing: return
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_row     = row
				_drag_pressed = true
			else:
				_drag_pressed = false
				_drag_row     = null
	)

# Global input handler — receives mouse motion even outside the row rect
func _input(event: InputEvent) -> void:
	if not _drag_pressed or _drag_row == null or is_executing: return
	if event is InputEventMouseButton and not event.pressed:
		_drag_pressed = false
		_drag_row     = null
		return
	if event is InputEventMouseMotion:
		_handle_drag_motion(_drag_row, event.global_position.y)

func _handle_drag_motion(row: HBoxContainer, global_y: float) -> void:
	if _std_workspace == null or not is_instance_valid(row): return
	var rows := _std_workspace.get_children()
	var my_idx := rows.find(row)
	if my_idx < 0: return
	var target_idx := rows.size() - 1
	for i in rows.size():
		var r := rows[i] as Control
		if r == null: continue
		if global_y < r.global_position.y + r.size.y * 0.5:
			target_idx = i
			break
	if target_idx == my_idx: return
	_std_workspace.move_child(row, target_idx)
	# Rebuild command_blocks to match new visual order
	command_blocks.clear()
	for r in _std_workspace.get_children():
		var b := _get_row_block(r)
		if b: command_blocks.append(b)
	_renumber_rows()

func _get_row_block(row: Node) -> CommandBlock:
	for child in row.get_children():
		if child is CommandBlock: return child
	return null

# Always renumbers sequentially 1,2,3… regardless of deletion or reorder
func _renumber_rows() -> void:
	if _std_workspace == null: return
	var idx := 1
	for row in _std_workspace.get_children():
		var lbl := row.get_node_or_null("LineNum")
		if lbl:
			lbl.text = str(idx)
			idx += 1

func _add_basic_cmd(cmd_type: CommandBlock.CommandType) -> void:
	_finalise_block(CommandBlock.new(cmd_type))

func _remove_cmd(block: CommandBlock) -> void:
	command_blocks.erase(block)
	# Block lives inside a row HBoxContainer — free the whole row
	var row = block.get_parent()
	if row and row is HBoxContainer:
		row.queue_free()
	elif row:
		row.remove_child(block)
		block.queue_free()
	_renumber_rows()
	_update_counter()

func _remove_last_cmd() -> void:
	if command_blocks.is_empty(): return
	_remove_cmd(command_blocks.back())

func _clear_commands() -> void:
	# Free row containers (which contain the CommandBlocks)
	if _std_workspace:
		for row in _std_workspace.get_children(): row.queue_free()
	else:
		for b in command_blocks: b.queue_free()
	command_blocks.clear()
	_update_counter()

func _refresh_palette(allowed: Array[String]) -> void:
	# Hide legacy left-panel buttons
	for b in [btn_up,btn_down,btn_left,btn_right,btn_attack,btn_loop,btn_append]:
		b.visible = false

	if _bottom_palette == null: return
	var hbox : HBoxContainer = _bottom_palette.get_meta("buttons_hbox")
	for child in hbox.get_children(): child.queue_free()

	var cmd_type_map : Dictionary = {
		"up": CommandBlock.CommandType.MOVE_UP, "down": CommandBlock.CommandType.MOVE_DOWN,
		"left": CommandBlock.CommandType.MOVE_LEFT, "right": CommandBlock.CommandType.MOVE_RIGHT,
		"attack": CommandBlock.CommandType.ATTACK,
	}

	for entry in PALETTE_BUTTONS:
		var key          : String = entry[0]
		var label        : String = entry[1]
		var tex_path     : String = entry[2]
		var hover_color  : Color  = entry[3]
		if not (allowed.is_empty() or allowed.has(key)): continue

		var btn := _make_palette_btn(label, tex_path, hover_color)
		btn.set_meta("cmd_key", key)
		if key == "loop":
			btn.pressed.connect(_on_loop_pressed)
		elif key == "append":
			btn.pressed.connect(_on_append_pressed)
		else:
			var ct : CommandBlock.CommandType = cmd_type_map[key]
			btn.pressed.connect(func(): _on_basic_pressed(ct))

		hbox.add_child(btn)

# ── Build one palette button ──────────────────────────────────────────────────
# If a texture asset is provided: fully transparent button, icon fills it,
# hover = icon scales up + yellow outline glow, pressed = icon scales down.
# If no asset: orange button with text (fallback).
func _make_palette_btn(label: String, tex_path: String, _hover_col: Color) -> Button:
	var has_tex : bool = tex_path != "" and ResourceLoader.exists(tex_path)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(88, 88)
	btn.focus_mode          = Control.FOCUS_NONE
	btn.clip_contents       = false   # allow icon to expand outside on hover

	# ── Fully transparent styles when using an asset ───────────────────────────
	var sty_empty := StyleBoxEmpty.new()
	if has_tex:
		for state in ["normal","hover","pressed","focus","disabled"]:
			btn.add_theme_stylebox_override(state, sty_empty)
	else:
		# Orange fallback styles
		var sty := StyleBoxFlat.new()
		sty.bg_color = Color(0.95, 0.55, 0.05, 1.0)
		for corner in ["top_left","top_right","bottom_left","bottom_right"]:
			sty.set("corner_radius_" + corner, 8)
		btn.add_theme_stylebox_override("normal", sty)
		var sty_h := sty.duplicate(); sty_h.bg_color = Color(1.0, 0.70, 0.20)
		btn.add_theme_stylebox_override("hover", sty_h)
		var sty_p := sty.duplicate(); sty_p.bg_color = Color(0.70, 0.38, 0.02)
		btn.add_theme_stylebox_override("pressed", sty_p)
		btn.text = label
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", Color.WHITE)
		return btn

	# ── Asset icon — fills the button, centered ────────────────────────────────
	var tex : Texture2D = load(tex_path)
	var tex_rect := TextureRect.new()
	tex_rect.name         = "Icon"
	tex_rect.texture      = tex
	tex_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Fill the button exactly at rest
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(tex_rect)

	# ── Glow outline panel — hidden by default, shown on hover/press ──────────
	# Uses a StyleBoxFlat border-only panel layered behind the icon.
	var glow := Panel.new()
	glow.name         = "Glow"
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible      = false
	var glow_sty      := StyleBoxFlat.new()
	glow_sty.bg_color       = Color(0, 0, 0, 0)   # transparent fill
	glow_sty.border_color   = Color(1.0, 0.95, 0.3, 1.0)
	for side in ["left","right","top","bottom"]:
		glow_sty.set("border_width_" + side, 3)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		glow_sty.set("corner_radius_" + corner, 6)
	glow.add_theme_stylebox_override("panel", glow_sty)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	btn.add_child(glow)

	# ── Hover / press animation via Tween ─────────────────────────────────────
	# We connect mouse_entered / mouse_exited on the button for scale feedback.
	# Pressed feedback uses button_down / button_up.
	var normal_scale  := Vector2(1.0, 1.0)
	var hover_scale   := Vector2(1.12, 1.12)   # 12% bigger on hover
	var pressed_scale := Vector2(0.92, 0.92)   # slightly smaller on press

	# Keep pivot centred whenever the icon is resized
	tex_rect.resized.connect(func(): tex_rect.pivot_offset = tex_rect.size * 0.5)

	btn.mouse_entered.connect(func():
		tex_rect.pivot_offset = tex_rect.size * 0.5
		glow.visible = true
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tex_rect, "scale", hover_scale, 0.12)
	)
	btn.mouse_exited.connect(func():
		glow.visible = false
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tex_rect, "scale", normal_scale, 0.10)
	)
	btn.button_down.connect(func():
		var tw := btn.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(tex_rect, "scale", pressed_scale, 0.07)
		glow_sty.border_color = Color(0, 0, 0, 0)   # orange tint on press
	)
	btn.button_up.connect(func():
		# Return to hover scale (mouse is still over the button)
		var tw := btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(tex_rect, "scale", hover_scale, 0.10)
		glow_sty.border_color = Color(1.0, 0.95, 0.3, 1.0)   # back to yellow
	)

	return btn

# ── Tutorial ───────────────────────────────────────────────────────────────────
func _show_tutorial(level_index: int) -> void:
	var steps := _get_tutorial_steps(level_index)
	if steps.is_empty(): return
	var overlay = TutorialOverlay.instantiate()
	$UI.add_child(overlay)
	overlay.tutorial_finished.connect(func(): run_button.disabled = false)
	run_button.disabled = true
	overlay.setup(steps)

# ══════════════════════════════════════════════════════════════════════════════
# TUTORIAL STEPS — edit here to change dialogue, pointers, or box positions.
#
# Each step is a Dictionary with these keys:
#   "text"        — RichTextLabel BBCode string shown in the dialogue box.
#                   Use [b]bold[/b] for emphasis.
#   "pointer_pos" — Vector2 screen position the arrow points to.
#                   Set to null to hide the pointer entirely.
#   "box_pos"     — (optional) Vector2 where the dialogue box appears.
#                   Defaults to DEFAULT_POS in tutorial_overlay.gd (210, 300).
#   "box_size"    — (optional) Vector2 size of the dialogue box.
#                   Defaults to DEFAULT_SIZE in tutorial_overlay.gd (720, 160).
#
# Pointer reference positions (1152×648 screen, standard palette-left layout):
#   Palette buttons (up/dn/lt/rt/atk/loop/append): x≈80, y≈40/80/120/160/200/240/280
#   Grid center:      Vector2(576, 272)
#   Workspace panel:  Vector2(576, 590)
#   Action counter:   Vector2(1060, 30)
#   Run button:       Vector2(1064, 624)
#   Backspace button: Vector2(1064, 580)
#
# Phase 2 layout (palette hidden, grid at x=16, right panel x=816..1146):
#   REPEAT spinbox:   Vector2(920,  50)
#   IF row:           Vector2(920,  90)
#   THEN row:         Vector2(920, 120)
#   ELSE row:         Vector2(920, 150)
#   Right panel mid:  Vector2(980, 270)
#   Blank dropdowns:  Vector2(920, 100) approx — adjust per level
#
# To add a tutorial for a new level, add a new "N:" case below
# where N is the zero-based index in the levels[] array.
# ══════════════════════════════════════════════════════════════════════════════
func _get_tutorial_steps(level_index: int) -> Array[Dictionary]:
	match level_index:

		# ── LEVEL 1 (index 0) ─────────────────────────────────────────────────
		0:
			return [
				{
					"text": "[b]Hey there, fellow programmer! Our company, PeaceTech, is about to release some groundbreaking system that can save the world.",
					"pointer_pos": null,
				},
				{
					"text": "[b]But wait! A cybersecurity attack from our rival TechSupport??",
					"pointer_pos": null,
				},
				{
					"text": "[b]Programmer, we need to save our project from the virus.",
					"pointer_pos": null,
				},
				{
					"text": "[b]If we solve the puzzles given to us, we’ll be able to regain control of our systems and bring world peace(?).",
					"pointer_pos": null,
				},
				{
					"text": "Your goal is to create a sequence of movements for the robot to successfully reach the exit.",
					"pointer_pos": Vector2(740, 220),   # points at the movement buttons in the palette
					"pointer_rotation": 135.0,
					"box_position": Vector2(300, 210)
				},
				{
					"text": "These buttons are your controls. Moving [b]Up, Down, Left, or Right[/b] slides the robot in that direction until it hits a wall.",
					"pointer_pos": Vector2(140, 490),   # points at the movement buttons in the palette
					"pointer_rotation": 135.0,
					"box_position": Vector2(140, 380)
				},
				{
					"text": "[b]&&  APPEND[/b] lets you combine two moves into a single action slot.",
					"pointer_pos": Vector2(480, 530),   # points at the Append button
					"pointer_rotation": 170.0,
					"box_position": Vector2(200, 380)
				},
				{
					"text": "Here is the command panel where the sequence of moves will appear once you start choosing the actions. [b]Right click[/b] on the move to delete.",
					"pointer_pos": Vector2(750, 120),  # points at the workspace panel
					"box_position": Vector2(350, 100)
				},
				{
					"text": "You can [b]Right-click[/b] to remove an action from the command panel",
					"pointer_pos": null,
				},
				{
					"text": "When you are ready, press [b]RUN PROGRAM[/b] to activate the sequence you just created.",
					"pointer_pos": Vector2(840, 580), # points at the Run button
					"pointer_rotation": 45.0,
					"box_position": Vector2(800, 400)
				},
				{
					"text": "But be careful of this counter. Each level has a specific limit on the actions you choose, so make sure you don’t go over the limit.",
					"pointer_pos": Vector2(900, 500),  # points at the action counter top-right
					"pointer_rotation": 70.0,
					"box_position": Vector2(800, 300)
				},
				{
					"text": "[b]We’re counting on you to save PeachTech. Good luck!",
					"pointer_pos": null,
				},
			]

		# ── LEVEL 2 (index 1) ─────────────────────────────────────────────────
		1:
			return [
				{
					"text": "[b]Nice job clearing the first level! But wait...",
					"pointer_pos": null,
				},
				{
					"text": "Boxes are blocking the path! The number on each box shows how many hits it takes to break it.",
					"pointer_pos": Vector2(580, 350),  # TODO: point at a collapsible block on the grid
					"pointer_rotation": 70.0
				},
				{
					"text": "Use [b]ATTACK[/b] to hit a box.",
					"pointer_pos": Vector2(380, 500),   # points at the Attack button in palette
					"pointer_rotation": 110.0,
					"box_position": Vector2(420, 400)
				},
				{
					"text": "You can also use [b]LOOP[/b] to hit it multiple times in one slot.",
					"pointer_pos": Vector2(480, 500),   # points at the Attack button in palette
					"pointer_rotation": 110.0,
					"box_position": Vector2(520, 400)
				},
				{
					"text": "You can try to Loop directional commands, but why would you need to, right? The robot slides until it hits a wall.",
					"pointer_pos": Vector2(480, 500),   # points at the Attack button in palette
					"pointer_rotation": 110.0,
					"box_position": Vector2(520, 400)
				},
			]

		# ── LEVEL 3 (index 2) ─────────────────────────────────────────────────
		2:
			return [
				{
					"text": "[b]Nice job keep it up!",
					"pointer_pos": null,
				},
				{
					"text": "[b]But before you proceed Let me explain [b]Even[/b] and [b]Odd[/b] blocks",
					"pointer_pos": null,
				},
				{
					"text": "[b]Even blocks[/b] only open when the action that reaches them is even-numbered — action 2, 4, 6, and so on.",
					"pointer_pos": Vector2(420, 60),   
					"pointer_rotation": 110.0,
					"box_position": Vector2(520, 120)
				},
				{
					"text": "[b]Odd blocks[/b] open on odd-numbered actions — 1, 3, 5...\n\nPlan your sequence carefully so you have a clear path when you need it!",
					"pointer_pos": Vector2(420, 320),   
					"pointer_rotation": 110.0,
					"box_position": Vector2(520, 320)
				},
			]

		# ── LEVEL 4 (index 3) ─────────────────────────────────────────────────
		3:
			return [
				{
					"text": "[b]Nice work!",
					"pointer_pos": null,
				},
				{
					"text": "[b]Oh yea...",
					"pointer_pos": null,
				},
				{
					"text": "A level can also have locked doors blocking the path.",
					"pointer_pos": Vector2(420, 400),   
					"pointer_rotation": 110.0,
					"box_position": Vector2(520, 420)
				},
				{
					"text": "Find and press the switch in order to open them!",
					"pointer_pos": Vector2(720, 60),   
					"pointer_rotation": 110.0,
					"box_position": Vector2(820, 160)
				},
				{
					"text": "[b]*Static*",
					"pointer_pos": null,
				},
				{
					"text": "[b]hel..o...I thin..I am discon...",
					"pointer_pos": null,
				},
			]

		# ── LEVEL 7 (index 6) — Phase 2 introduction ──────────────────────────
		6:
			return [
				{
					"text": "[b]Hello? Hello? Nice I have restored the communication line.",
					"pointer_pos": null,
				},
				{
					"text": "Before you go further — the system is handing you something new.\n\nUp until now you've been pressing commands one by one. This sector is different. You'll be given a [b]blueprint[/b] — a program that's already half-written. Your job is to fill in the blanks.",
					"pointer_pos": null,
				},
				{
					"text": "See the [b]LOOP[/b] block? It runs whatever is inside it 6 times in a row. Each time it runs, it checks the situation fresh.\n\nHere's the key difference: the robot now moves [b]exactly one tile per iteration[/b]. It does not slide. So adjust the number of times it will loop by increasing or decreasing the number. ",
					"pointer_pos": Vector2(880, 25),   # points at the REPEAT header / spinbox
					"box_position": Vector2(400, 50)
				},
				{
					"text": "Inside the repeat there is always an [b]IF[/b] and an [b]ELSE[/b].\n\nEvery iteration, the robot asks the IF question. If the answer is yes — it does the IF action. If no — it does the ELSE action. One or the other. Never both.",
					"pointer_pos": Vector2(750, 75),  
					"box_position": Vector2(350, 50)
				},
				{
					"text": "The condition always looks like: [b]direction == Free[/b]\n\n[b]==[/b] means 'is equal to' — it is asking a question, not setting something.",
					"pointer_pos": Vector2(925, 70),   # points at the IF condition row
					"box_position": Vector2(400, 50)
				},
				{
					"text": "To the left of the == is a drop down with directions: Up, Down, Left and Right.",
					"pointer_pos": Vector2(850, 75),  
					"box_position": Vector2(400, 50)
				},
				{
					"text": "To the right of the == is a drop down with the conditions: \n [b]Free[/b], means the tile is passable.\n and \n [b]Obstacle[/b], means it is blocked.",
					"pointer_pos": Vector2(950, 75),  
					"box_position": Vector2(400, 50)
				},
				{
					"text": "Putting them together looks like this \n If Up == Free ",
					"pointer_pos": null,  
					"box_position": Vector2(350, 50)
				},
				{
					"text": "This is asking if the tile above you is free. If this is true the robot will then do the 'then' command. If it's false the robot will then do the 'else' command.",
					"pointer_pos": null,  
					"box_position": Vector2(350, 50)  
				},
				{
					"text": "So this: If Left == Obstacle means if the tile to your left is an obstacle then the robot will do the 'then' command. If not the robot will then do the 'else' command.",
					"pointer_pos": null,  
					"box_position": Vector2(350, 50)
				},
				{
					"text": "That's pretty much the gist of it. \n\nThe structure is fixed. You choose what goes inside — the direction to check, the condition, and what action to take to reach the exit.",
					"pointer_pos": null
				},
				{
					"text": "So fill in all the dropdowns and hit RUN. You've seen how this works — now figure it out yourself!",
					"pointer_pos": null
				},
			]

		# ── LEVEL 9 (index 8) — first independent attempt ─────────────────────
		8:
			return [
				{
					"text": "[b]Good work! Just keep going!",
					"pointer_pos": null,
				},
			]
					# ── LEVEL 10 (index 9) — first independent attempt ─────────────────────
		9:
			return [
				{
					"text": "[b]Good work! You're almost there!",
					"pointer_pos": null,
				},
			]

		# ── Add new levels below this line ────────────────────────────────────
		# Example:
		# 9:  # Level 10 (index 9)
		#   return [
		#     { "text": "Your dialogue here.", "pointer_pos": Vector2(x, y) },
		#   ]

	return []

# ── UI helpers ─────────────────────────────────────────────────────────────────
func _set_palette_hint(msg: String) -> void:
	var lbl = get_node_or_null("UI/CommandPalette/HintLabel")
	if lbl: lbl.text = msg
	btn_loop.modulate   = Color.YELLOW if _pending_mode == PendingMode.LOOP else Color.WHITE
	btn_append.modulate = Color.CYAN   if _pending_mode in [PendingMode.APPEND_FIRST, PendingMode.APPEND_SECOND] else Color.WHITE
	_update_action_button_visuals()
	
func _clear_palette_hint() -> void:
	var lbl = get_node_or_null("UI/CommandPalette/HintLabel")
	if lbl: lbl.text = ""
	btn_loop.modulate   = Color.WHITE
	btn_append.modulate = Color.WHITE
	_update_action_button_visuals()

func _highlight(cmd: CommandBlock) -> void:
	_clear_highlights(); cmd.modulate = Color.YELLOW

func _clear_highlights() -> void:
	for cmd in command_blocks: cmd.modulate = Color.WHITE

func _update_counter() -> void:
	if _is_if_else_mode: return
	var n : int = command_blocks.size()
	count_label.text = "%d / %d" % [n, max_actions]
	count_label.add_theme_color_override("font_color",
		Color.GREEN if n < max_actions else Color.YELLOW)

func _show_failure_flash() -> void:
	if count_label and not _is_if_else_mode:
		count_label.add_theme_color_override("font_color", Color.RED)
		count_label.text = "RESET!"
	for cmd in command_blocks: cmd.modulate = Color.RED
	await get_tree().create_timer(0.4).timeout
	for cmd in command_blocks: cmd.modulate = Color.WHITE

func _flash_error() -> void:
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	count_label.add_theme_color_override("font_color", Color.RED)
	await get_tree().create_timer(0.3).timeout
	_update_counter()
	

# ── Loop Count Popup ───────────────────────────────────────────────────────────
func _show_loop_count_popup() -> void:
	# Create dim overlay
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	$UI.add_child(dim)

	# Create centered popup panel
	var popup := PanelContainer.new()
	var popup_style := StyleBoxFlat.new()
	popup_style.bg_color = Color(0.15, 0.15, 0.25, 1.0)
	popup_style.border_color = Color(0.95, 0.55, 0.05, 1.0)
	for side in ["left","right","top","bottom"]:
		popup_style.set("border_width_" + side, 3)
	popup_style.corner_radius_top_left = 8
	popup_style.corner_radius_top_right = 8
	popup_style.corner_radius_bottom_left = 8
	popup_style.corner_radius_bottom_right = 8
	popup.add_theme_stylebox_override("panel", popup_style)
	
	# Center on screen
	popup.anchor_left = 0.5
	popup.anchor_right = 0.5
	popup.anchor_top = 0.5
	popup.anchor_bottom = 0.5
	popup.offset_left = -100
	popup.offset_right = 100
	popup.offset_top = -90
	popup.offset_bottom = 90
	
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	popup.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Loop Count"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	vbox.add_child(title)

	# Number buttons (1-9)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)
	
	for i in range(1, 10):
		var btn := Button.new()
		btn.text = str(i)
		btn.custom_minimum_size = Vector2(35, 35)
		btn.add_theme_font_size_override("font_size", 14)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.1333, 0.9294, 0.1725, 1.0)
		btn_style.corner_radius_top_left = 5
		btn_style.corner_radius_top_right = 5
		btn_style.corner_radius_bottom_left = 5
		btn_style.corner_radius_bottom_right = 5
		btn.add_theme_stylebox_override("normal", btn_style)
		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = Color(0.2431, 0.9373, 0.2745, 1.0)
		btn.add_theme_stylebox_override("hover", btn_hover)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.pressed.connect(func():
			_pending_loop_count = i
			_pending_mode = PendingMode.LOOP
			_set_palette_hint("Pick action to loop ×%d…" % i)
			dim.queue_free()
			popup.queue_free()
		)
		hbox.add_child(btn)

	# Cancel button
	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(100, 32)
	cancel_btn.add_theme_font_size_override("font_size", 13)
	cancel_btn.pressed.connect(func():
		dim.queue_free()
		popup.queue_free()
	)
	vbox.add_child(cancel_btn)

	$UI.add_child(popup)


# ── Update action button visuals for pending modes ────────────────────────────
# ── Update action button visuals for pending modes ────────────────────────────
func _update_action_button_visuals() -> void:
	if _bottom_palette == null: return
	var hbox : HBoxContainer = _bottom_palette.get_meta("buttons_hbox")
	
	# Define which button keys are action buttons (not loop/append)
	var action_keys := ["up", "down", "left", "right", "attack"]
	
	for child in hbox.get_children():
		if child is Button:
			# Get the button's key from metadata
			var btn_key : String = child.get_meta("cmd_key", "")
			var is_action_btn : bool = btn_key in action_keys
			
			# Check if we're in LOOP or APPEND mode
			var is_pending : bool = _pending_mode in [PendingMode.LOOP, PendingMode.APPEND_FIRST, PendingMode.APPEND_SECOND]
			
			if is_action_btn and is_pending:
				# Add orange border when waiting for action selection (NO FILL)
				var sty := StyleBoxFlat.new()
				sty.bg_color = Color(0, 0, 0, 0)  # ← Transparent (no fill)
				sty.border_color = Color(1.0, 0.95, 0.3, 1.0)  # Yellow/orange border
				for side in ["left","right","top","bottom"]:
					sty.set("border_width_" + side, 3)
				for corner in ["top_left","top_right","bottom_left","bottom_right"]:
					sty.set("corner_radius_" + corner, 6)
				child.add_theme_stylebox_override("normal", sty)
				
				var sty_hover := sty.duplicate()
				sty_hover.border_color = Color(1.0, 0.85, 0.1, 1.0)
				child.add_theme_stylebox_override("hover", sty_hover)
				child.add_theme_stylebox_override("pressed", sty)
			else:
				# Restore original style (transparent fill, no border)
				var sty := StyleBoxFlat.new()
				sty.bg_color = Color(0, 0, 0, 0)  # ← Transparent (no fill)
				sty.border_color = Color(0, 0, 0, 0)  # No border
				for side in ["left","right","top","bottom"]:
					sty.set("border_width_" + side, 2)
				for corner in ["top_left","top_right","bottom_left","bottom_right"]:
					sty.set("corner_radius_" + corner, 6)
				child.add_theme_stylebox_override("normal", sty)
				
				var sty_hover := sty.duplicate()
				sty_hover.border_color = Color(1.0, 0.65, 0.15, 1.0)
				child.add_theme_stylebox_override("hover", sty_hover)
				child.add_theme_stylebox_override("pressed", sty_hover)

func _show_ending_screen() -> void:
	var ending = EndingScreen.instantiate()
	$UI.add_child(ending)
	ending.setup(_attempt_counts)  # Pass the attempt counts dictionary
	
