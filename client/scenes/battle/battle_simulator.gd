# BattleSimulator - Client-side battle simulation engine
class_name BattleSimulator
extends Node

class BattleUnit:
	var max_hp: float = 100.0
	var hp: float = 100.0
	var atk: float = 10.0
	var def_val: float = 5.0  # "def" is reserved
	var crit_rate: float = 0.05
	var crit_dmg: float = 1.5
	var atk_speed: float = 1.0

	func take_damage(raw: float) -> float:
		var actual: float = max(raw - def_val * 0.3, raw * 0.1)
		hp = max(hp - actual, 0)
		return actual

class WaveData:
	var monsters: Array[BattleUnit] = []
	var is_boss: bool = false

class BattleSummary:
	var stage_id: String = ""
	var total_damage_dealt: float = 0.0
	var total_damage_taken: float = 0.0
	var clear_time_ms: int = 0
	var waves: Array = []
	var skills_used: Array = []
	var skill_cast_counts: Dictionary = {}
	var player_stats: Dictionary = {}
	var hp_before: float = 0.0
	var hp_after: float = 0.0
	var boss_defeated: bool = false
	var monster_kills: int = 0

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
			"hp_before": hp_before,
			"hp_after": hp_after,
			"boss_defeated": boss_defeated,
			"monster_kills": monster_kills,
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

func start_battle(stage_config: Dictionary, player_stats: Dictionary) -> void:
	player = _create_unit(player_stats)
	waves = _parse_waves(stage_config)
	summary = BattleSummary.new()
	summary.stage_id = stage_config.get("stage_id", "unknown")
	summary.player_stats = player_stats
	summary.skills_used = []
	summary.skill_cast_counts = {}
	summary.hp_before = player.hp
	summary.hp_after = player.hp
	summary.boss_defeated = false
	summary.monster_kills = 0
	current_wave = 0
	elapsed_time = 0.0
	_elapsed_player_attack = 0.0
	_elapsed_monster_attack = 0.0
	wave_damage = 0.0
	wave_damage_taken = 0.0
	Log.info("BattleSimulator", "Battle started", {
		"stage_id": summary.stage_id,
		"waves": waves.size(),
		"player_hp": player.max_hp,
		"player_atk": player.atk,
	})

func _create_unit(stats: Dictionary) -> BattleUnit:
	var unit := BattleUnit.new()
	unit.max_hp = stats.get("hp", 100)
	unit.hp = stats.get("hp", 100)
	unit.atk = stats.get("atk", 10)
	unit.def_val = stats.get("def", 5)
	unit.crit_rate = stats.get("crit_rate", 0.05)
	unit.crit_dmg = stats.get("crit_dmg", 1.5)
	unit.atk_speed = stats.get("atk_speed", 1.0)
	return unit

func _parse_waves(config: Dictionary) -> Array:
	var result: Array[WaveData] = []
	var wave_list: Variant = config.get("waves", config.get("config", {}).get("waves", []))
	if wave_list is Array:
		for w: Dictionary in wave_list:
			var wd := WaveData.new()
			wd.is_boss = w.get("is_boss", false)
			wd.monsters = []
			var monster_list: Variant = w.get("monsters", [])
			if monster_list is Array:
				for m: Dictionary in monster_list:
					for _i: int in range(m.get("count", 1)):
						var unit := BattleUnit.new()
						unit.max_hp = m.get("hp", 100)
						unit.hp = m.get("hp", 100)
						unit.atk = m.get("atk", 10)
						unit.def_val = m.get("def", 5)
						wd.monsters.append(unit)
			result.append(wd)
	return result

func tick(delta: float) -> void:
	elapsed_time += delta
	if current_wave >= waves.size():
		return

	var wave: WaveData = waves[current_wave]
	var attack_interval: float = 1.0 / max(player.atk_speed, 0.1)

	# Player attack (attacks nearest alive monster)
	_elapsed_player_attack += delta
	if _elapsed_player_attack >= attack_interval:
		_elapsed_player_attack -= attack_interval
		for monster: BattleUnit in wave.monsters:
			if monster.hp > 0:
				var dmg: float = _calc_damage(player.atk, monster.def_val, player.crit_rate, player.crit_dmg)
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
		for monster: BattleUnit in wave.monsters:
			if monster.hp > 0:
				var dmg: float = _calc_damage(monster.atk, player.def_val, 0.0, 0.0)
				player.take_damage(dmg)
				summary.total_damage_taken += dmg
				wave_damage_taken += dmg

	# Check if player is defeated
	if player.hp <= 0:
		_finish_battle()
		return

	# Check wave cleared
	if _wave_cleared(wave):
		var kills: int = wave.monsters.size()
		summary.monster_kills += kills
		if wave.is_boss:
			summary.boss_defeated = true
		summary.waves.append({
			"wave": current_wave + 1,
			"kills": kills,
			"damage": wave_damage,
			"damage_taken": wave_damage_taken,
			"is_boss": wave.is_boss,
		})
		wave_damage = 0
		wave_damage_taken = 0
		current_wave += 1
		if current_wave >= waves.size():
			_finish_battle()

func _try_cast_skills(delta: float) -> void:
	var equipped: Array = PlayerState.skill_equipped
	var skills_data: Array = PlayerState.skill_inventory
	for skill_id: Variant in equipped:
		if skill_id == null or skill_id == "":
			continue
		var sid: String = str(skill_id)
		# Tick cooldown
		if not _skill_cooldowns.has(sid):
			_skill_cooldowns[sid] = 0.0
		if _skill_cooldowns[sid] > 0:
			_skill_cooldowns[sid] = max(_skill_cooldowns[sid] - delta, 0.0)
			continue
		# Cast skill when ready
		var skill_info: Dictionary = _find_skill_info(sid, skills_data)
		if skill_info.is_empty():
			continue
		var wave: WaveData = waves[current_wave]
		var coef: float = skill_info.get("coeff", 1.0)
		var effect: String = skill_info.get("effect_type", "damage")
		match effect:
			"damage":
				var target: String = skill_info.get("effect_params", {}).get("target", "single")
				if target == "aoe":
					for monster: BattleUnit in wave.monsters:
						if monster.hp > 0:
							var dmg: float = _calc_damage(player.atk * coef, monster.def_val, player.crit_rate, player.crit_dmg)
							monster.take_damage(dmg)
							summary.total_damage_dealt += dmg
							wave_damage += dmg
				else:
					for monster: BattleUnit in wave.monsters:
						if monster.hp > 0:
							var dmg: float = _calc_damage(player.atk * coef, monster.def_val, player.crit_rate, player.crit_dmg)
							monster.take_damage(dmg)
							summary.total_damage_dealt += dmg
							wave_damage += dmg
							break
			"buff":
				var params: Dictionary = skill_info.get("effect_params", {})
				if params.get("type") == "shield":
					pass  # Shield logic placeholder
		# Track usage
		if not summary.skill_cast_counts.has(sid):
			summary.skill_cast_counts[sid] = 0
		summary.skill_cast_counts[sid] += 1
		if not summary.skills_used.has(sid):
			summary.skills_used.append(sid)
		# Set cooldown
		_skill_cooldowns[sid] = skill_info.get("cooldown", 3.0)

func _find_skill_info(skill_id: String, skills_data: Array) -> Dictionary:
	for s: Dictionary in skills_data:
		if s.get("skill_id", s.get("id", "")) == skill_id:
			return s
	return {}

func _wave_cleared(wave: WaveData) -> bool:
	for m: BattleUnit in wave.monsters:
		if m.hp > 0:
			return false
	return true

func _finish_battle() -> void:
	summary.clear_time_ms = int(elapsed_time * 1000)
	summary.hp_after = max(player.hp, 0.0)
	Log.info("BattleSimulator", "Battle finished", {
		"stage_id": summary.stage_id,
		"clear_time_ms": summary.clear_time_ms,
		"damage_dealt": summary.total_damage_dealt,
		"damage_taken": summary.total_damage_taken,
		"waves_cleared": current_wave,
	})
	battle_ended.emit(summary)

func _calc_damage(atk: float, def_val: float, crit_rate: float, crit_dmg: float) -> float:
	var base: float = max(atk - def_val * 0.3, atk * 0.1)
	if randf() < crit_rate:
		base *= crit_dmg
	return base
