class_name CharacterModel
extends RefCounted

var id: int
var nickname: String
var class_name: String
var level: int
var exp: int
var exp_to_next: int
var gold: int
var skill_tickets: int
var stats: Dictionary
var cp: float

func from_dict(d: Dictionary):
	id = d.get("id", 0)
	nickname = d.get("nickname", "")
	class_name = d.get("class", "warrior")
	level = d.get("level", 1)
	exp = d.get("exp", 0)
	exp_to_next = d.get("exp_to_next", 100)
	gold = d.get("gold", 0)
	skill_tickets = d.get("skill_tickets", 0)
	stats = d.get("stats", {})
	cp = d.get("cp", 0.0)
	return self
