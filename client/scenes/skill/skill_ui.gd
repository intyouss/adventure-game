extends Control

@onready var slot_1 = $SkillSlots/Slot1
@onready var slot_2 = $SkillSlots/Slot2
@onready var slot_3 = $SkillSlots/Slot3
@onready var slot_4 = $SkillSlots/Slot4
@onready var innate_slot = $SkillSlots/InnateSlot
@onready var skill_list = $SkillList
@onready var ticket_label = $TicketLabel
@onready var gacha_1 = $GachaButtons/Gacha1
@onready var gacha_10 = $GachaButtons/Gacha10
@onready var gacha_50 = $GachaButtons/Gacha50
@onready var gacha_100 = $GachaButtons/Gacha100

var _selected_skill_index: int = -1

func _ready():
	gacha_1.pressed.connect(func(): _do_gacha(1))
	gacha_10.pressed.connect(func(): _do_gacha(10))
	gacha_50.pressed.connect(func(): _do_gacha(50))
	gacha_100.pressed.connect(func(): _do_gacha(100))
	skill_list.item_selected.connect(_on_skill_selected)
	EventBus.skill_updated.connect(_on_skills_changed)
	EventBus.skill_tickets_changed.connect(_update_tickets)
	_setup_slot_drag()
	_refresh()

func _load_shop_info():
	var res = await NetworkManager.request("GET", "/api/skill/shop_info")
	if res.code == 0:
		var data = res.data
		PlayerState.shop_level = data.get("shop_level", 1)
		if data.has("total_pulls"):
			PlayerState.character["total_pulls"] = data.total_pulls
		if data.has("pulls_to_next"):
			PlayerState.character["pulls_to_next"] = data.pulls_to_next
		PlayerState.character["active_qualities"] = data.get("active_qualities", [])

func _setup_slot_drag():
	if innate_slot:
		innate_slot.disabled = true
		innate_slot.modulate = Color(0.5, 0.5, 0.5, 1.0)
		innate_slot.text = "[固定技能]"

	var slots = [slot_1, slot_2, slot_3, slot_4]
	for i in range(slots.size()):
		var s = slots[i]
		var slot_idx = i
		s.pressed.connect(func(): _on_slot_tapped(slot_idx))

func _on_skills_changed():
	_render()

func _refresh():
	await PlayerState.load_skills()
	await _load_shop_info()
	_render()

func _render():
	print("[UI] action=refresh_skill_standalone")
	skill_list.clear()
	for i in range(PlayerState.skill_inventory.size()):
		var skill = PlayerState.skill_inventory[i]
		skill_list.add_item("%s Lv.%d [%d卡]" % [skill.get("name", skill.get("skill_id", "?")), skill.get("level", 1), skill.get("count", skill.get("cards", 1))])
	_update_slots()
	_update_tickets(PlayerState.character.get("skill_tickets", 0))

func _update_slots():
	var equipped = PlayerState.skill_equipped
	if equipped.size() >= 1:
		slot_1.text = _slot_text(equipped[0] if equipped[0] != null else "")
	else:
		slot_1.text = "[空]"
	if equipped.size() >= 2:
		slot_2.text = _slot_text(equipped[1] if equipped[1] != null else "")
	else:
		slot_2.text = "[空]"
	if equipped.size() >= 3:
		slot_3.text = _slot_text(equipped[2] if equipped[2] != null else "")
	else:
		slot_3.text = "[空]"
	if equipped.size() >= 4:
		slot_4.text = _slot_text(equipped[3] if equipped[3] != null else "")
	else:
		slot_4.text = "[空]"

func _slot_text(skill_id) -> String:
	if skill_id == null or skill_id == "":
		return "[空]"
	var skill_name = _find_skill_name(str(skill_id))
	return skill_name if skill_name != "" else str(skill_id)

func _find_skill_name(skill_id: String) -> String:
	for skill in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "")
	return ""

func _update_tickets(amount: int):
	print("[UI] action=update_tickets amount=", amount)
	ticket_label.text = "商店Lv.%d | 技能券: %d | 累计抽取: %d | 距升级: %d抽" % [
		PlayerState.shop_level,
		amount,
		PlayerState.character.get("total_pulls", 0),
		PlayerState.character.get("pulls_to_next", 0)
	]

func _on_skill_selected(index: int):
	_selected_skill_index = index

func _on_slot_tapped(slot_idx: int):
	print("[UI] skill_slot_tap idx=", slot_idx)
	if _selected_skill_index < 0 or _selected_skill_index >= PlayerState.skill_inventory.size():
		return
	var skill = PlayerState.skill_inventory[_selected_skill_index]
	var skill_id = skill.get("skill_id", skill.get("id", ""))
	var res = await NetworkManager.request("POST", "/api/skill/equip", {"skill_id": skill_id, "slot": slot_idx})
	if res.code == 0:
		await PlayerState.load_skills()
		_refresh()

func _do_gacha(count: int):
	print("[UI] skill_gacha count=", count)
	var res = await NetworkManager.request("POST", "/api/skill/gacha", {"count": count})
	if res.code == 0:
		var results = res.data.get("results", res.data.get("skills", []))
		for skill in results:
			EventBus.item_obtained.emit(skill)
		await PlayerState.load_skills()
		_refresh()
