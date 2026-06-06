class_name SkillModel
extends RefCounted

var id: String
var name: String
var quality: int
var level: int
var cards: int
var coeff: float

func from_dict(d: Dictionary):
	id = d.get("id", "")
	name = d.get("name", "")
	quality = d.get("quality", 1)
	level = d.get("level", 1)
	cards = d.get("cards", 1)
	coeff = d.get("coeff", 1.0)
	return self
