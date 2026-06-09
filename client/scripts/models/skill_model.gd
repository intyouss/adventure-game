# SkillModel - Skill data model with 5-tier quality
class_name SkillModel
extends RefCounted

var id: String = ""
var name: String = ""
var quality: int = 1
var level: int = 1
var cards: int = 1
var multiplier: float = 1.0
var description: String = ""

const QUALITY_COLORS: Dictionary = {
	1: Color(0.63, 0.63, 0.63),   # White - 普通
	2: Color(0.29, 0.87, 0.50),   # Green - 优良
	3: Color(0.38, 0.65, 0.93),   # Blue - 稀有
	4: Color(0.62, 0.48, 0.92),   # Purple - 史诗
	5: Color(0.93, 0.56, 0.21),   # Orange - 传说
}

const QUALITY_NAMES: Dictionary = {
	1: "普通", 2: "优良", 3: "稀有", 4: "史诗", 5: "传说",
}

func from_dict(d: Dictionary) -> SkillModel:
	id = d.get("id", d.get("skill_id", ""))
	name = d.get("name", "")
	quality = d.get("quality", 1)
	level = d.get("level", 1)
	cards = d.get("cards", d.get("count", 1))
	multiplier = d.get("multiplier", d.get("coeff", 1.0))
	description = d.get("description", "")
	return self

func get_quality_color() -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

func get_quality_name() -> String:
	return QUALITY_NAMES.get(quality, "???")
