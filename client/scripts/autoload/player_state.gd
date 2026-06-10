# PlayerState - Client-side player data cache
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

func update_from_server(data: Dictionary) -> void:
	if data.has("character"):
		character.merge(data["character"], true)
		EventBus.stats_changed.emit()
	if data.has("stats"):
		stats = data["stats"]
		EventBus.stats_changed.emit()
	if data.has("equipment_inventory"):
		equipment_inventory = data["equipment_inventory"]
		EventBus.inventory_changed.emit()
	if data.has("equipped"):
		equipped = data["equipped"]
	if data.has("skill_inventory"):
		skill_inventory = data["skill_inventory"]
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
		stage_chapter = data.get("chapter", stage_progress.get("chapter", 1))
		stage_level = data.get("level", stage_progress.get("level", 1))
	if data.has("rewards"):
		EventBus.reward_received.emit(data.rewards)
	Log.info("PlayerState", "Data updated from server", {
		"has_character": data.has("character"),
		"has_stats": data.has("stats"),
		"has_equipment": data.has("equipment_inventory"),
		"has_skills": data.has("skill_inventory"),
	})

func clear() -> void:
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
	stage_chapter = 1
	stage_level = 1
	Log.info("PlayerState", "State cleared")

# ── Data Loaders ──────────────────────────────────────

func load_character() -> bool:
	var res: Dictionary = await NetworkManager.request("GET", "/api/character")
	if res.code == 0:
		character = res.data
		EventBus.stats_changed.emit()
		Log.info("PlayerState", "Character loaded", {"level": character.get("level", 0), "nickname": character.get("nickname", "")})
		return true
	Log.warn("PlayerState", "Failed to load character", {"msg": res.get("msg", "")})
	return false

func load_equipment() -> bool:
	var res: Dictionary = await NetworkManager.request("GET", "/api/equipment/inventory")
	if res.code == 0:
		equipment_inventory = res.data.get("items", [])
		equipped = res.data.get("equipped", {})
		EventBus.inventory_changed.emit()
		Log.info("PlayerState", "Equipment loaded", {"items": equipment_inventory.size(), "slots": equipped.size()})
		return true
	Log.warn("PlayerState", "Failed to load equipment", {"msg": res.get("msg", "")})
	return false

func load_skills() -> bool:
	var res1: Dictionary = await NetworkManager.request("GET", "/api/skill/list")
	if res1.code == 0:
		skill_inventory = res1.data.get("skills", [])
	var res2: Dictionary = await NetworkManager.request("GET", "/api/skill/slots")
	if res2.code == 0:
		skill_equipped = res2.data.get("equipped", [])
	EventBus.skill_updated.emit()
	Log.info("PlayerState", "Skills loaded", {"inventory": skill_inventory.size(), "equipped": skill_equipped.size()})
	return true

func load_chest_info() -> bool:
	var res: Dictionary = await NetworkManager.request("GET", "/api/chest/info")
	if res.code == 0:
		chest_count = res.data.chest_count
		zone_level = res.data.zone_level
		Log.info("PlayerState", "Chest info loaded", {"chests": chest_count, "zone_level": zone_level})
		return true
	Log.warn("PlayerState", "Failed to load chest info", {"msg": res.get("msg", "")})
	return false

func load_progress() -> bool:
	var res: Dictionary = await NetworkManager.request("GET", "/api/stage/progress")
	if res.code == 0:
		stage_progress = res.data
		stage_chapter = res.data.get("chapter", 1)
		stage_level = res.data.get("level", 1)
		Log.info("PlayerState", "Progress loaded", {"chapter": stage_chapter, "level": stage_level})
		return true
	Log.warn("PlayerState", "Failed to load progress", {"msg": res.get("msg", "")})
	return false

func load_all() -> void:
	Log.info("PlayerState", "Loading all data...")
	await load_character()
	await load_equipment()
	await load_skills()
	await load_chest_info()
	await load_progress()
	EventBus.inventory_changed.emit()
	EventBus.skill_updated.emit()
	Log.info("PlayerState", "All data loaded", {
		"level": character.get("level", 0),
		"equipment": equipment_inventory.size(),
		"skills": skill_inventory.size(),
		"chests": chest_count,
		"chapter": stage_chapter,
		"stage": stage_level,
	})
