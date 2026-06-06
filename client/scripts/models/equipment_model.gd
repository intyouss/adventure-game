class_name EquipmentModel
extends RefCounted

var id: String
var slot: String
var quality: int
var atk: int
var def: int
var hp: int

var QUALITY_COLORS = {
	1: Color.WHITE,
	2: Color.GREEN,
	3: Color.DODGER_BLUE,
	4: Color.PURPLE,
	5: Color.ORANGE,
	6: Color.RED,
	7: Color.GOLD,
}

var QUALITY_NAMES = {
	1: "普通", 2: "优秀", 3: "稀有", 4: "精良", 5: "史诗", 6: "传说", 7: "神话",
}

var SLOT_NAMES = {
	"weapon": "武器", "helmet": "头盔", "armor": "衣服", "shoes": "鞋子",
	"ring1": "戒指1", "ring2": "戒指2", "necklace": "项链", "bracer": "护腕",
	"belt": "腰带", "gloves": "手套",
}

func from_dict(d: Dictionary):
	id = d.get("id", "")
	slot = d.get("slot", "")
	quality = d.get("quality", 1)
	atk = d.get("atk", 0)
	def = d.get("def", 0)
	hp = d.get("hp", 0)
	return self

func get_quality_color() -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

func get_quality_name() -> String:
	return QUALITY_NAMES.get(quality, "???")

func get_slot_name() -> String:
	return SLOT_NAMES.get(slot, slot)
