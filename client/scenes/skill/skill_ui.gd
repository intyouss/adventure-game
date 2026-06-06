extends Control

@onready var slot_1 = $SkillSlots/Slot1
@onready var slot_2 = $SkillSlots/Slot2
@onready var slot_3 = $SkillSlots/Slot3
@onready var slot_4 = $SkillSlots/Slot4
@onready var skill_list = $SkillList
@onready var ticket_label = $TicketLabel
@onready var gacha_1 = $GachaButtons/Gacha1
@onready var gacha_10 = $GachaButtons/Gacha10

var _selected_skill_id: String = ""

func _ready():
	gacha_1.pressed.connect(func(): _do_gacha(1))
	gacha_10.pressed.connect(func(): _do_gacha(10))
	EventBus.skills_updated.connect(_refresh)
	EventBus.skill_tickets_changed.connect(_update_tickets)
	_refresh()

func _refresh():
	skill_list.clear()
	for skill in PlayerState.skills:
		skill_list.add_item("%s Lv.%d [%d卡]" % [skill.name, skill.level, skill.cards])
	_update_slots()
	_update_tickets(PlayerState.character.get("skill_tickets", 0))

func _update_slots():
	var slots = PlayerState.skill_slots
	slot_1.text = _slot_text(slots.get("1", ""))
	slot_2.text = _slot_text(slots.get("2", ""))
	slot_3.text = _slot_text(slots.get("3", ""))
	slot_4.text = _slot_text(slots.get("4", ""))

func _slot_text(skill_id: String) -> String:
	if skill_id == "": return "[空]"
	return skill_id

func _update_tickets(amount: int):
	ticket_label.text = "技能券: %d" % amount

func _do_gacha(count: int):
	var res = await NetworkManager.request("POST", "/api/skill/gacha", {"count": count})
	if res.code == 0:
		for skill in res.data.skills:
			EventBus.item_obtained.emit(skill)
		await PlayerState.load_skills()
		_refresh()
