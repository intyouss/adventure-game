extends Control

@onready var stage_name_label = $StageName
@onready var battle_scene = $BattleScene
@onready var skill_slot_0 = $SkillSlots/Slot0
@onready var skill_slot_1 = $SkillSlots/Slot1
@onready var skill_slot_2 = $SkillSlots/Slot2
@onready var skill_slot_3 = $SkillSlots/Slot3
@onready var skill_slot_4 = $SkillSlots/Slot4

var _slots: Array = []

func _ready():
	_slots = [skill_slot_0, skill_slot_1, skill_slot_2, skill_slot_3, skill_slot_4]
	_setup_innate_slot()
	EventBus.skill_updated.connect(_refresh_skill_slots)
	EventBus.login_success.connect(_refresh_stage_title)
	EventBus.auto_login_success.connect(_refresh_stage_title)
	_refresh_skill_slots()
	_refresh_stage_title()
	_setup_battle_display()

func _setup_innate_slot():
	skill_slot_0.disabled = true
	skill_slot_0.modulate = Color(1.0, 0.75, 0.0)
	skill_slot_0.text = "🔥"

func _chapter_name(chapter: int) -> String:
	var names = {
		1: "第一章", 2: "第二章", 3: "第三章", 4: "第四章", 5: "第五章",
		6: "第六章", 7: "第七章", 8: "第八章", 9: "第九章", 10: "第十章"
	}
	return names.get(chapter, "第%d章" % chapter)

func _refresh_stage_title():
	var chapter = PlayerState.stage_chapter
	var level = PlayerState.stage_level
	stage_name_label.text = "%s %d-%d" % [_chapter_name(chapter), chapter, level]

func _setup_battle_display():
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_scene.add_child(row)

	# Character left
	var char_label = Label.new()
	char_label.text = "🧙 角色"
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_label.add_theme_font_size_override("font_size", 20)
	row.add_child(char_label)

	# VS center
	var vs_label = Label.new()
	vs_label.text = "⚔ VS ⚔"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs_label.add_theme_font_size_override("font_size", 18)
	row.add_child(vs_label)

	# Monster right
	var mon_label = Label.new()
	mon_label.text = "👹 怪物"
	mon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mon_label.add_theme_font_size_override("font_size", 20)
	row.add_child(mon_label)

func _refresh_skill_slots():
	print("[UI] refresh_skill_slots count=", PlayerState.skill_equipped.size())
	var equipped = PlayerState.skill_equipped
	for i in range(1, 5):
		var slot = _slots[i]
		if i - 1 < equipped.size() and equipped[i - 1] != null and equipped[i - 1] != "":
			var skill_name = _find_skill_name(str(equipped[i - 1]))
			slot.text = skill_name if skill_name != "" else "?"
			slot.modulate = Color.WHITE
		else:
			slot.text = "+"
			slot.modulate = Color(0.3, 0.3, 0.3)

func _find_skill_name(skill_id: String) -> String:
	for skill in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "")
	return ""
