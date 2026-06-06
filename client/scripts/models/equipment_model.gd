class_name EquipmentModel
extends RefCounted

var id: String
var slot: String
var quality: int
var atk: int
var def: int
var hp: int
var crit_rate: float
var atk_speed: float

const QUALITY_COLORS = {
	1: Color.WHITE,
	2: Color.GREEN,
	3: Color.DODGER_BLUE,
	4: Color.PURPLE,
	5: Color.ORANGE,
	6: Color.RED,
	7: Color.GOLD,
}

const QUALITY_NAMES = {
	1: "普通", 2: "优秀", 3: "稀有", 4: "史诗", 5: "传说", 6: "神话", 7: "神赐",
}

const SLOT_NAMES = {
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
	crit_rate = d.get("crit_rate", 0.0)
	atk_speed = d.get("atk_speed", 0.0)
	return self

func get_quality_color() -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

func get_quality_name() -> String:
	return QUALITY_NAMES.get(quality, "???")

func get_slot_name() -> String:
	return SLOT_NAMES.get(slot, slot)
