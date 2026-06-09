# CharacterModel - Player character data model
class_name CharacterModel
extends RefCounted

var account_id: int = 0
var id: int = 0
var nickname: String = ""
var class_type: String = "warrior"
var level: int = 1
var exp: int = 0
var atk: int = 10
var def_val: int = 5  # "def" is a reserved keyword in GDScript context
var hp: int = 100
var gold: int = 0
var skill_tickets: int = 0
var stats: Dictionary = {}
var cp: float = 0.0

func calc_cp() -> float:
	return (atk * 2.0 + def_val * 1.5 + hp * 0.5) * (1.0 + level * 0.1)

func exp_to_next_level() -> int:
	return int(100 * pow(1.15, level - 1))

func from_dict(d: Dictionary) -> CharacterModel:
	account_id = d.get("account_id", 0)
	id = d.get("id", 0)
	nickname = d.get("nickname", "")
	class_type = d.get("class", "warrior")
	level = d.get("level", 1)
	exp = d.get("exp", 0)
	atk = d.get("atk", d.get("base_atk", 10))
	def_val = d.get("def", d.get("base_def", 5))
	hp = d.get("hp", d.get("base_hp", 100))
	gold = d.get("gold", 0)
	skill_tickets = d.get("skill_tickets", 0)
	stats = d.get("stats", {})
	cp = d.get("cp", calc_cp())
	return self
