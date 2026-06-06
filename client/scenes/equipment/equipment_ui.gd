extends Control

@onready var slot_grid = $SlotGrid
@onready var inventory_list = $InventoryList
@onready var detail_popup = $DetailPopup
@onready var decompose_btn = $DecomposeBtn

var _selected_equip_id: String = ""

func _ready():
	EventBus.inventory_updated.connect(_refresh)
	_refresh()

func _refresh():
	inventory_list.clear()
	for item in PlayerState.inventory:
		inventory_list.add_item("%s [%s] ATK:%d DEF:%d HP:%d" % [
			EquipmentModel.new().from_dict(item).get_slot_name(),
			EquipmentModel.new().from_dict(item).get_quality_name(),
			item.atk, item.def, item.hp
		])
	_update_slots()

func _update_slots():
	for slot_name in ["weapon","helmet","armor","shoes","ring1","ring2","necklace","bracer","belt","gloves"]:
		var equip_id = PlayerState.equipped.get(slot_name, "")
		if equip_id:
			# Show equipped item
			pass

func _on_inventory_selected(index: int):
	if index >= 0 and index < PlayerState.inventory.size():
		_selected_equip_id = PlayerState.inventory[index].id
		detail_popup.visible = true

func _on_equip():
	if _selected_equip_id:
		await NetworkManager.request("POST", "/api/equipment/equip", {"equip_id": _selected_equip_id, "slot": "weapon"})
		await PlayerState.load_equipment()
		_refresh()

func _on_decompose():
	if _selected_equip_id:
		var res = await NetworkManager.request("POST", "/api/equipment/decompose", {"equip_id": _selected_equip_id})
		if res.code == 0:
			EventBus.gold_changed.emit(res.data.gold_gained)
		await PlayerState.load_equipment()
		_refresh()
