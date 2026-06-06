extends Control

@onready var chapter_tabs = $ChapterTabs
@onready var stage_name_label = $StageName
@onready var battle_scene = $BattleScene
@onready var skill_slot_0 = $SkillSlots/Slot0
@onready var skill_slot_1 = $SkillSlots/Slot1
@onready var skill_slot_2 = $SkillSlots/Slot2
@onready var skill_slot_3 = $SkillSlots/Slot3
@onready var skill_slot_4 = $SkillSlots/Slot4

var _slots: Array = []
var _current_chapter: int = 1
var _current_stage: String = ""

func _ready():
	_slots = [skill_slot_0, skill_slot_1, skill_slot_2, skill_slot_3, skill_slot_4]
	_setup_innate_slot()
	_setup_chapter_tabs()
	EventBus.skill_updated.connect(_refresh_skill_slots)
	_refresh_skill_slots()

func _setup_innate_slot():
	skill_slot_0.disabled = true
	skill_slot_0.modulate = Color(1.0, 0.75, 0.0)
	skill_slot_0.text = "🔥"

func _setup_chapter_tabs():
	var chapters = 10
	for ch in range(1, chapters + 1):
		var btn = Button.new()
		btn.text = "第%d章" % ch
		btn.toggle_mode = true
		var chapter = ch
		btn.pressed.connect(func(): _switch_chapter(chapter))
		chapter_tabs.add_child(btn)
		if ch == 1:
			btn.button_pressed = true
	_switch_chapter(1)

func _switch_chapter(chapter: int):
	_current_chapter = chapter
	_load_stages()

func _load_stages():
	for child in battle_scene.get_children():
		child.queue_free()

	var res = await NetworkManager.request("GET", "/api/stage/config?chapter=%d" % _current_chapter)
	var stages = []
	if res.code == 0:
		var data = res.data
		if data is Array:
			stages = data
		else:
			stages = data.get("stages", data.get("configs", []))
	else:
		for i in range(1, 11):
			stages.append({"stage_id": "%d-%d" % [_current_chapter, i], "level": i})

	for cfg in stages:
		var stage_id = cfg.get("stage_id", "")
		var level = cfg.get("level", 1)
		var unlocked = _is_unlocked(level)
		var btn = Button.new()
		btn.text = stage_id
		btn.disabled = not unlocked
		var sid = stage_id
		btn.pressed.connect(func(): _start_battle(sid))
		battle_scene.add_child(btn)

func _is_unlocked(level: int) -> bool:
	if _current_chapter < PlayerState.stage_chapter:
		return true
	if _current_chapter == PlayerState.stage_chapter:
		return level <= PlayerState.stage_level
	return false

func _start_battle(stage_id: String):
	_current_stage = stage_id
	stage_name_label.text = stage_id
	EventBus.battle_started.emit(stage_id)
	var bc = load("res://scenes/battle/battle_controller.gd").new()
	get_tree().root.add_child(bc)
	bc.start_stage(stage_id)

func _refresh_skill_slots():
	var equipped = PlayerState.skill_equipped
	for i in range(1, 5):
		var slot = _slots[i]
		if i - 1 < equipped.size() and equipped[i - 1] != null and equipped[i - 1] != "":
			var name = _find_skill_name(str(equipped[i - 1]))
			slot.text = name if name != "" else "?"
			slot.modulate = Color.WHITE
		else:
			slot.text = "+"
			slot.modulate = Color(0.3, 0.3, 0.3)

func _find_skill_name(skill_id: String) -> String:
	for skill in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "")
	return ""
