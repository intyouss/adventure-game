class_name CharacterModel
extends RefCounted

var account_id: int
var id: int
var nickname: String
var class_name: String
var level: int
var exp: int
var atk: int
var def: int
var hp: int
var gold: int
var skill_tickets: int
var stats: Dictionary
var cp: float

func calc_cp() -> float:
	return (atk * 2 + def * 1.5 + hp * 0.5) * (1 + level * 0.1)

func exp_to_next_level() -> int:
	return int(100 * pow(1.15, level - 1))

func from_dict(d: Dictionary):
	account_id = d.get("account_id", 0)
	id = d.get("id", 0)
	nickname = d.get("nickname", "")
	class_name = d.get("class", "warrior")
	level = d.get("level", 1)
	exp = d.get("exp", 0)
	atk = d.get("atk", d.get("base_atk", 10))
	def = d.get("def", d.get("base_def", 5))
	hp = d.get("hp", d.get("base_hp", 100))
	gold = d.get("gold", 0)
	skill_tickets = d.get("skill_tickets", 0)
	stats = d.get("stats", {})
	cp = d.get("cp", calc_cp())
	return self
