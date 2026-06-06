class_name SkillModel
extends RefCounted

var id: String
var name: String
var quality: int
var level: int
var cards: int
var multiplier: float
var description: String

const QUALITY_COLORS = {
	1: Color.WHITE,
	2: Color.GREEN,
	3: Color.DODGER_BLUE,
	4: Color.PURPLE,
	5: Color.ORANGE,
}

const QUALITY_NAMES = {
	1: "普通", 2: "优秀", 3: "稀有", 4: "史诗", 5: "传说",
}

func from_dict(d: Dictionary):
	id = d.get("id", "")
	name = d.get("name", "")
	quality = d.get("quality", 1)
	level = d.get("level", 1)
	cards = d.get("cards", 1)
	multiplier = d.get("multiplier", d.get("coeff", 1.0))
	description = d.get("description", "")
	return self

func get_quality_color() -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)

func get_quality_name() -> String:
	return QUALITY_NAMES.get(quality, "???")
