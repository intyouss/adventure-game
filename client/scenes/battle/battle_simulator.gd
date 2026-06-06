class_name BattleSimulator
extends Node

class BattleUnit:
	var max_hp: float
	var hp: float
	var atk: float
	var def: float
	var crit_rate: float
	var crit_dmg: float
	var atk_speed: float

	func take_damage(raw: float) -> float:
		var actual = max(raw - def * 0.3, raw * 0.1)
		hp = max(hp - actual, 0)
		return actual

class WaveData:
	var monsters: Array
	var is_boss: bool

class BattleSummary:
	var stage_id: String
	var total_damage_dealt: float
	var total_damage_taken: float
	var clear_time_ms: int
	var waves: Array
	var skills_used: Array
	var skill_cast_counts: Dictionary
	var player_stats: Dictionary

	func to_dict() -> Dictionary:
		return {
			"stage_id": stage_id,
			"total_damage_dealt": total_damage_dealt,
			"total_damage_taken": total_damage_taken,
			"clear_time_ms": clear_time_ms,
			"waves": waves,
			"skills_used": skills_used,
			"skill_cast_counts": skill_cast_counts,
			"player_stats": player_stats,
		}

var player: BattleUnit
var waves: Array[WaveData] = []
var summary: BattleSummary
var current_wave: int = 0
var elapsed_time: float = 0.0
var _elapsed_player_attack: float = 0.0
var _elapsed_monster_attack: float = 0.0
var wave_damage: float = 0.0
var wave_damage_taken: float = 0.0
var _skill_cooldowns: Dictionary = {}

signal battle_ended(summary: BattleSummary)

func start_battle(stage_config: Dictionary, player_stats: Dictionary):
	player = _create_unit(player_stats)
	waves = _parse_waves(stage_config)
	summary = BattleSummary.new()
	summary.stage_id = stage_config.get("stage_id", "unknown")
	summary.player_stats = player_stats
	summary.skills_used = []
	summary.skill_cast_counts = {}
	current_wave = 0
	elapsed_time = 0.0
	_elapsed_player_attack = 0.0
	_elapsed_monster_attack = 0.0
	wave_damage = 0.0
	wave_damage_taken = 0.0

func _create_unit(stats: Dictionary) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.max_hp = stats.get("hp", 100)
	unit.hp = stats.get("hp", 100)
	unit.atk = stats.get("atk", 10)
	unit.def = stats.get("def", 5)
	unit.crit_rate = stats.get("crit_rate", 0.05)
	unit.crit_dmg = stats.get("crit_dmg", 1.5)
	unit.atk_speed = stats.get("atk_speed", 1.0)
	return unit

func _parse_waves(config: Dictionary) -> Array:
	var result: Array = []
	var wave_list = config.get("waves", config.get("config", {}).get("waves", []))
	for w in wave_list:
		var wd = WaveData.new()
		wd.is_boss = w.get("is_boss", false)
		wd.monsters = []
		for m in w.get("monsters", []):
			for _i in range(m.get("count", 1)):
				var unit = BattleUnit.new()
				unit.max_hp = m.get("hp", 100)
				unit.hp = m.get("hp", 100)
				unit.atk = m.get("atk", 10)
				unit.def = m.get("def", 5)
				wd.monsters.append(unit)
		result.append(wd)
	return result

func tick(delta: float):
	elapsed_time += delta
	if current_wave >= waves.size():
		return

	var wave = waves[current_wave]
	var attack_interval = 1.0 / max(player.atk_speed, 0.1)

	# Player attack (attacks nearest alive monster)
	_elapsed_player_attack += delta
	if _elapsed_player_attack >= attack_interval:
		_elapsed_player_attack -= attack_interval
		for monster in wave.monsters:
			if monster.hp > 0:
				var dmg = _calc_damage(player.atk, monster.def, player.crit_rate, player.crit_dmg)
				monster.take_damage(dmg)
				summary.total_damage_dealt += dmg
				wave_damage += dmg
				break

	# Skill casting
	_try_cast_skills(delta)

	# Monster attacks - gate with 1.0s interval per monster
	_elapsed_monster_attack += delta
	if _elapsed_monster_attack >= 1.0:
		_elapsed_monster_attack -= 1.0
		for monster in wave.monsters:
			if monster.hp > 0:
				var dmg = _calc_damage(monster.atk, player.def, 0.0, 0.0)
				player.take_damage(dmg)
				summary.total_damage_taken += dmg
				wave_damage_taken += dmg

	# Check if player is defeated
	if player.hp <= 0:
		_finish_battle()
		return

	# Check wave cleared
	if _wave_cleared(wave):
		summary.waves.append({
			"wave": current_wave + 1,
			"kills": wave.monsters.size(),
			"damage": wave_damage,
			"damage_taken": wave_damage_taken,
			"is_boss": wave.is_boss,
		})
		wave_damage = 0
		wave_damage_taken = 0
		current_wave += 1
		if current_wave >= waves.size():
			_finish_battle()

func _try_cast_skills(delta: float):
	var equipped = PlayerState.skill_equipped
	var skills_data = PlayerState.skill_inventory
	for skill_id in equipped:
		if skill_id == null or skill_id == "":
			continue
		# Tick cooldown
		if not _skill_cooldowns.has(skill_id):
			_skill_cooldowns[skill_id] = 0.0
		if _skill_cooldowns[skill_id] > 0:
			_skill_cooldowns[skill_id] = max(_skill_cooldowns[skill_id] - delta, 0.0)
			continue
		# Cast skill when ready
		var skill_info = _find_skill_info(skill_id, skills_data)
		if skill_info.is_empty():
			continue
		var wave = waves[current_wave]
		var coef = skill_info.get("coeff", 1.0)
		var effect = skill_info.get("effect_type", "damage")
		match effect:
			"damage":
				var target = skill_info.get("effect_params", {}).get("target", "single")
				if target == "aoe":
					for monster in wave.monsters:
						if monster.hp > 0:
							var dmg = _calc_damage(player.atk * coef, monster.def, player.crit_rate, player.crit_dmg)
							monster.take_damage(dmg)
							summary.total_damage_dealt += dmg
							wave_damage += dmg
				else:
					for monster in wave.monsters:
						if monster.hp > 0:
							var dmg = _calc_damage(player.atk * coef, monster.def, player.crit_rate, player.crit_dmg)
							monster.take_damage(dmg)
							summary.total_damage_dealt += dmg
							wave_damage += dmg
							break
			"buff":
				if effect == "buff":
					var params = skill_info.get("effect_params", {})
					if params.get("type") == "shield":
						pass  # Shield logic placeholder
		# Track usage
		if not summary.skill_cast_counts.has(skill_id):
			summary.skill_cast_counts[skill_id] = 0
		summary.skill_cast_counts[skill_id] += 1
		if not summary.skills_used.has(skill_id):
			summary.skills_used.append(skill_id)
		# Set cooldown
		_skill_cooldowns[skill_id] = skill_info.get("cooldown", 3.0)

func _find_skill_info(skill_id: String, skills_data: Array) -> Dictionary:
	for s in skills_data:
		if s.get("skill_id", s.get("id", "")) == skill_id:
			return s
	return {}

func _wave_cleared(wave: WaveData) -> bool:
	for m in wave.monsters:
		if m.hp > 0:
			return false
	return true

func _finish_battle():
	summary.clear_time_ms = int(elapsed_time * 1000)
	battle_ended.emit(summary)

func _calc_damage(atk: float, def: float, crit_rate: float, crit_dmg: float) -> float:
	var base = max(atk - def * 0.3, atk * 0.1)
	if randf() < crit_rate:
		base *= crit_dmg
	return base
