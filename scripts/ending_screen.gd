extends CanvasLayer
var _winning_actions : Dictionary = {}
# ── Dialogue steps shown before the log is revealed ───────────────────────────
const ENDING_DIALOGUE : Array[Dictionary] = [
	{ "text": "..." },
	{ "text": "You did it." },
	{ "text": "Every sector cleared. Every virus neutralized." },
	{ "text": "PeaceTech's systems are restored. The world peace project is back online." },
	{ "text": "I... didn't think you'd actually pull it off. But here we are." },
	{ "text": "You're a better programmer than I gave you credit for." },
	{ "text": "Before you go — the research team wants a record of your run.\nEvery level. Every attempt. All of it." },
	{ "text": "Take a look. You've earned it." },
]

# ── Phase boundaries (zero-based level indices) ────────────────────────────────
const PHASE1_NAMES : Array[String] = [
	"Level 1 - Tutorial", "Level 2 - Breakables", "Level 3", "Level 4", "Level 5", "Level 6"
]
const PHASE2_NAMES : Array[String] = [
	"Level 7 - The Algorithm", "Level 8", "Level 9", "Level 9 - Alt",
	"Final Level", "Final Level - Alt"
]

var _attempt_counts : Dictionary = {}
var _dialogue_index : int = 0
var _typing         : bool = false
var _full_text      : String = ""

@onready var _dim          : ColorRect   = $Dim
@onready var _dialogue_box : PanelContainer = $DialogueBox
@onready var _rich_label   : RichTextLabel  = $DialogueBox/Margin/VBox/RichLabel
@onready var _next_btn     : Button         = $DialogueBox/Margin/VBox/NextBtn
@onready var _log_panel    : PanelContainer = $LogPanel
@onready var _log_vbox     : VBoxContainer  = $LogPanel/Margin/OuterVBox/ScrollContainer/LogVBox
@onready var _menu_btn     : Button         = $LogPanel/Margin/OuterVBox/MenuBtn

func setup(attempt_counts: Dictionary, winning_actions: Dictionary) -> void:
	_attempt_counts = attempt_counts
	_winning_actions = winning_actions  # ⭐ Store winning actions
	_dialogue_index = 0
	_log_panel.visible = false
	_dialogue_box.visible = true
	_show_step(_dialogue_index)

func _show_step(index: int) -> void:
	if index >= ENDING_DIALOGUE.size():
		_finish_dialogue()
		return
	_full_text  = ENDING_DIALOGUE[index].get("text", "")
	_rich_label.text = ""
	_next_btn.text   = "▶"
	_typing = true
	_type_text()

func _type_text() -> void:
	var chars_per_frame := 2
	var current := _rich_label.text.length()
	while current < _full_text.length() and _typing:
		_rich_label.text += _full_text[current]
		current += 1
		if current % chars_per_frame == 0:
			await get_tree().process_frame
	_typing = false
	_next_btn.text = "Next  ▶" if _dialogue_index < ENDING_DIALOGUE.size() - 1 else "See Results  ▶"

func _on_next_pressed() -> void:
	if _typing:
		# Skip typing — show full text immediately
		_typing = false
		_rich_label.text = _full_text
		_next_btn.text = "Next  ▶" if _dialogue_index < ENDING_DIALOGUE.size() - 1 else "See Results  ▶"
		return
	_dialogue_index += 1
	_show_step(_dialogue_index)

func _finish_dialogue() -> void:
	_dialogue_box.visible = false
	_build_log()
	_log_panel.visible = true

func _build_log() -> void:
	# Clear previous contents except the MenuBtn
	for child in _log_vbox.get_children():
		child.queue_free()

	_add_section_header("📋  Run Summary")
	_add_separator()

	# ── Phase 1 ───────────────────────────────────────────────────────────────
	_add_phase_header("— Phase 1: Sequence Programming —")
	for lvl_name in PHASE1_NAMES:
		var attempts : int = _attempt_counts.get(lvl_name, 0) as int
		_add_row(lvl_name, attempts, true)  # ⭐ is_phase1 = true

	_add_separator()

	# ── Phase 2 ───────────────────────────────────────────────────────────────
	_add_phase_header("— Phase 2: Repeat-If-Else —")
	for lvl_name in PHASE2_NAMES:
		if _attempt_counts.has(lvl_name):
			var attempts : int = _attempt_counts.get(lvl_name, 0) as int
			_add_row(lvl_name, attempts, false)  # ⭐ is_phase1 = false

	_add_separator()

	# ── Total ─────────────────────────────────────────────────────────────────
	var total : int = 0
	for v in _attempt_counts.values():
		total += v as int
	_add_total_row(total)
	
func _add_section_header(txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_vbox.add_child(lbl)

func _add_phase_header(txt: String) -> void:
	var lbl := Label.new()
	lbl.text = txt
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log_vbox.add_child(lbl)

func _add_row(lvl_name: String, attempts: int, is_phase1: bool = false) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	name_lbl.text = lvl_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	row.add_child(name_lbl)

	var info_vbox := VBoxContainer.new()
	info_vbox.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(info_vbox)

	# Failed attempts label
	var att_lbl := Label.new()
	var color : Color
	if attempts == 0:
		att_lbl.text = "✔ First try!"
		color = Color(0.2, 0.9, 0.4)
	elif attempts == 1:
		att_lbl.text = "1 failed attempt"
		color = Color(1.0, 0.85, 0.3)
	else:
		att_lbl.text = "%d failed attempts" % attempts
		color = Color(1.0, 0.5, 0.3)
	att_lbl.add_theme_font_size_override("font_size", 13)
	att_lbl.add_theme_color_override("font_color", color)
	att_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_vbox.add_child(att_lbl)

	# ⭐ Phase 1: Show winning action count
	if is_phase1 and _winning_actions.has(lvl_name):
		var actions := _winning_actions[lvl_name] as int
		var max_actions := _get_max_actions(lvl_name)
		var action_lbl := Label.new()
		action_lbl.text = "Win: %d/%d actions" % [actions, max_actions]
		action_lbl.add_theme_font_size_override("font_size", 11)
		action_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
		action_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info_vbox.add_child(action_lbl)

	_log_vbox.add_child(row)
	
func _add_total_row(total: int) -> void:
	var row := HBoxContainer.new()

	var lbl := Label.new()
	lbl.text = "Total failed attempts:"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	row.add_child(lbl)

	var val := Label.new()
	val.text = str(total)
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val)

	_log_vbox.add_child(row)

func _get_max_actions(lvl_name: String) -> int:
	match lvl_name:
		"Level 1": return 5
		"Level 2": return 10
		"Level 3": return 8
		"Level 4": return 12
		"Level 5": return 10
		"Level 6": return 14
		_: return 8

func _add_separator() -> void:
	_log_vbox.add_child(HSeparator.new())

func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _ready() -> void:
	_next_btn.pressed.connect(_on_next_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)
