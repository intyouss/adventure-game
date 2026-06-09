# EquipmentArea - Equipment slot display (view-only, no unequip per v4 spec)
class_name EquipmentArea
extends Control

const SLOTS: Array[String] = ["weapon", "helmet", "armor", "shoes", "ring1", "ring2", "necklace", "bracer", "belt", "gloves"]
const SLOT_NAMES: Dictionary = {
	"weapon": "武器", "helmet": "头盔", "armor": "铠甲", "shoes": "鞋子",
	"ring1": "戒指1", "ring2": "戒指2", "necklace": "项链", "bracer": "护腕",
	"belt": "腰带", "gloves": "手套",
}

@onready var slot_grid: GridContainer = $SlotGrid

func _ready() -> void:
	EventBus.inventory_changed.connect(_refresh)
	_refresh()
	Log.info("EquipmentArea", "Equipment area ready (view-only, no unequip)")

func _refresh() -> void:
	Log.debug("EquipmentArea", "Refreshing equipment display")
	for slot_name: String in SLOTS:
		var equip_uid: Variant = PlayerState.equipped.get(slot_name, "")
		var btn: Button = slot_grid.get_node_or_null(slot_name)
		if not btn or not btn is Button:
			continue

		if equip_uid != "" and equip_uid != null:
			var found: Dictionary = _find_item_by_uid(str(equip_uid))
			if not found.is_empty():
				var model := EquipmentModel.new().from_dict(found)
				btn.text = "%s\n%s" % [SLOT_NAMES.get(slot_name, slot_name), model.get_quality_name()]
				btn.modulate = model.get_quality_color()
			else:
				btn.text = "%s\n[空]" % SLOT_NAMES.get(slot_name, slot_name)
				btn.modulate = Color.WHITE
		else:
			btn.text = "%s\n[空]" % SLOT_NAMES.get(slot_name, slot_name)
			btn.modulate = Color.WHITE

func _find_item_by_uid(uid: String) -> Dictionary:
	for item: Dictionary in PlayerState.equipment_inventory:
		if item.get("uid", item.get("id", "")) == uid:
			return item
	return {}
