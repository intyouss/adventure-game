extends Node

var character: Dictionary = {}
var stats: Dictionary = {}
var equipment_inventory: Array = []
var equipped: Dictionary = {}
var skill_inventory: Array = []
var skill_equipped: Array = []
var chest_count: int = 0
var zone_level: int = 1
var shop_level: int = 1
var stage_progress: Dictionary = {}
var stage_chapter: int = 1
var stage_level: int = 1

signal character_updated
signal stats_changed
signal inventory_changed
signal skill_updated

func update_from_server(data: Dictionary):
	if data.has("character"):
		character.merge(data["character"], true)
		character_updated.emit()
	if data.has("stats"):
		stats = data["stats"]
		stats_changed.emit()
	if data.has("equipment_inventory"):
		equipment_inventory = data["equipment_inventory"]
		inventory_changed.emit()
		EventBus.inventory_changed.emit()
	if data.has("equipped"):
		equipped = data["equipped"]
	if data.has("skill_inventory"):
		skill_inventory = data["skill_inventory"]
		skill_updated.emit()
		EventBus.skill_updated.emit()
	if data.has("skill_equipped"):
		skill_equipped = data["skill_equipped"]
	if data.has("chest_count"):
		chest_count = data["chest_count"]
	if data.has("zone_level"):
		zone_level = data["zone_level"]
	if data.has("shop_level"):
		shop_level = data["shop_level"]
	if data.has("stage_progress"):
		stage_progress = data["stage_progress"]

func clear():
	character = {}
	stats = {}
	equipment_inventory = []
	equipped = {}
	skill_inventory = []
	skill_equipped = []
	chest_count = 0
	zone_level = 1
	shop_level = 1
	stage_progress = {}

func load_character():
	var res = await NetworkManager.request("GET", "/api/character")
	if res.code == 0:
		character = res.data
		character_updated.emit()

func load_equipment():
	var res = await NetworkManager.request("GET", "/api/equipment/inventory")
	if res.code == 0:
		equipment_inventory = res.data.get("items", []) if res.data.get("items") != null else []
		equipped = res.data.get("equipped", {}) if res.data.get("equipped") != null else {}
		inventory_changed.emit()

func load_skills():
	var res = await NetworkManager.request("GET", "/api/skill/list")
	if res.code == 0:
		skill_inventory = res.data.get("skills", []) if res.data.get("skills") != null else []
	var res2 = await NetworkManager.request("GET", "/api/skill/slots")
	if res2.code == 0:
		skill_equipped = res2.data.get("equipped", []) if res2.data.get("equipped") != null else []
	skill_updated.emit()

func load_chest_info():
	var res = await NetworkManager.request("GET", "/api/chest/info")
	if res.code == 0:
		chest_count = res.data.chest_count
		zone_level = res.data.zone_level

func load_progress():
	var res = await NetworkManager.request("GET", "/api/stage/progress")
	if res.code == 0:
		stage_progress = res.data
		stage_chapter = res.data.get("chapter", 1)
		stage_level = res.data.get("level", 1)

func load_all():
	await load_character()
	await load_equipment()
	await load_skills()
	await load_chest_info()
	await load_progress()
	# Emit EventBus signals once after all data is loaded
	EventBus.inventory_changed.emit()
	EventBus.skill_updated.emit()
