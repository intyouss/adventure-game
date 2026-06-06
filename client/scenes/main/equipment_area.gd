extends Control

const SLOTS = ["weapon","helmet","armor","shoes","ring1","ring2","necklace","bracer","belt","gloves"]
const SLOT_NAMES = {
	"weapon":"武器","helmet":"头盔","armor":"铠甲","shoes":"鞋子",
	"ring1":"戒指1","ring2":"戒指2","necklace":"项链","bracer":"护腕","belt":"腰带","gloves":"手套"
}

@onready var slot_grid = $SlotGrid

func _ready():
	EventBus.inventory_changed.connect(_refresh)
	_refresh()

func _refresh():
	for slot_name in SLOTS:
		var equip_uid = PlayerState.equipped.get(slot_name, "")
		var btn = slot_grid.get_node_or_null(slot_name)
		if not btn or not btn is Button:
			continue
		if equip_uid != "" and equip_uid != null:
			var found = _find_item_by_uid(equip_uid)
			if not found.is_empty():
				var model = EquipmentModel.new().from_dict(found)
				btn.text = "%s\n%s" % [SLOT_NAMES.get(slot_name, slot_name), model.get_quality_name()]
				btn.modulate = model.get_quality_color()
			else:
				btn.text = "%s\n[空]" % SLOT_NAMES.get(slot_name, slot_name)
				btn.modulate = Color.WHITE
		else:
			btn.text = "%s\n[空]" % SLOT_NAMES.get(slot_name, slot_name)
			btn.modulate = Color.WHITE

		var slot_name_for_connect = slot_name
		btn.pressed.connect(func(): _on_unequip(slot_name_for_connect))

func _on_unequip(slot_name: String):
	var equip_uid = PlayerState.equipped.get(slot_name, "")
	if equip_uid == "" or equip_uid == null:
		return
	await NetworkManager.request("POST", "/api/equipment/unequip", {"slot": slot_name})
	await PlayerState.load_equipment()
	_refresh()

func _find_item_by_uid(uid: String) -> Dictionary:
	for item in PlayerState.equipment_inventory:
		if item.get("uid", item.get("id", "")) == uid:
			return item
	return {}
