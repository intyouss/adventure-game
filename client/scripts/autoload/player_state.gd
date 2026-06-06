extends Node

var character: Dictionary = {}
var inventory: Array = []
var equipped: Dictionary = {}
var skills: Array = []
var skill_slots: Dictionary = {}
var chest_count: int = 0
var zone_level: int = 1
var shop_level: int = 1
var stage_chapter: int = 1
var stage_level: int = 1

signal character_updated
signal inventory_updated
signal skills_updated

func load_character():
	var res = await NetworkManager.request("GET", "/api/character")
	if res.code == 0:
		character = res.data
		character_updated.emit()

func load_equipment():
	var res = await NetworkManager.request("GET", "/api/equipment/inventory")
	if res.code == 0:
		inventory = res.data.inventory
		equipped = res.data.equipped
		inventory_updated.emit()

func load_skills():
	var res = await NetworkManager.request("GET", "/api/skill/list")
	if res.code == 0:
		skills = res.data.skills
		skill_slots = res.data.slots
		skills_updated.emit()

func load_chest_info():
	var res = await NetworkManager.request("GET", "/api/chest/info")
	if res.code == 0:
		chest_count = res.data.chest_count
		zone_level = res.data.zone_level

func load_progress():
	var res = await NetworkManager.request("GET", "/api/stage/progress")
	if res.code == 0:
		stage_chapter = res.data.chapter
		stage_level = res.data.level

func load_all():
	await load_character()
	await load_equipment()
	await load_skills()
	await load_chest_info()
	await load_progress()
