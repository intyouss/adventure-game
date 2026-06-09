# EquipmentModel - Equipment data model with 7-tier quality
class_name EquipmentModel
extends RefCounted

var name: String = ""
var id: String = ""
var uid: String = ""
var slot: String = ""
var quality: int = 1
var atk: int = 0
var def_val: int = 0  # "def" is a reserved keyword
var hp: int = 0
var crit_rate: float = 0.0
var atk_speed: float = 0.0

const QUALITY_COLORS: Dictionary = {
	1: Color(0.63, 0.63, 0.63),   # White - 普通
	2: Color(0.29, 0.87, 0.50),   # Green - 优良
	3: Color(0.38, 0.65, 0.93),   # Blue - 稀有
	4: Color(0.62, 0.48, 0.92),   # Purple - 史诗
	5: Color(0.93, 0.56, 0.21),   # Orange - 传说
	6: Color(0.97, 0.44, 0.44),   # Red - 神话
	7: Color(0.93, 0.80, 0.29),   # Gold - 神祼
}

const QUALITY_NAMES: Dictionary = {
	1: "普通", 2: "优良", 3: "稀有", 4: "史诗",
	5: "传说", 6: "神话", 7: "神祼",
}

const SLOT_NAMES: Dictionary = {
	"weapon": "武器", "helmet": "头盔", "armor": "铠甲", "shoes": "鞋子",
	"ring1": "戒指1", "ring2": "戒指2", "necklace": "项链", "bracer": "护腕",
	"belt": "腰带", "gloves": "手套",
}

func from_dict(d: Dictionary) -> EquipmentModel:
	name = d.get("name", "")
	id = d.get("id", "")
	uid = d.get("uid", d.get("id", ""))
	slot = d.get("slot", "")
	quality = d.get("quality", 1)
	atk = d.get("atk", 0)
	def_val = d.get("def", 0)
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
