class_name BattleSimulator
extends RefCounted

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
var _elapsed_attack: float = 0.0
var wave_damage: float = 0.0
var wave_damage_taken: float = 0.0
var _skill_cooldowns: Dictionary = {}

signal battle_ended(summary: BattleSummary)

func start_battle(stage_config: Dictionary, player_stats: Dictionary):
	player = _create_unit(player_stats)
	waves = _parse_waves(stage_config)
	summary = BattleSummary.new()
	summary.stage_id = stage_config.stage_id
	summary.player_stats = player_stats
	current_wave = 0
	elapsed_time = 0.0

func _create_unit(stats: Dictionary) -> BattleUnit:
	var unit = BattleUnit.new()
	unit.max_hp = stats.hp
	unit.hp = stats.hp
	unit.atk = stats.atk
	unit.def = stats.def
	unit.crit_rate = stats.get("crit_rate", 0.05)
	unit.crit_dmg = stats.get("crit_dmg", 1.5)
	unit.atk_speed = stats.get("atk_speed", 1.0)
	return unit

func _parse_waves(config: Dictionary) -> Array:
	var result: Array = []
	for w in config.waves:
		var wd = WaveData.new()
		wd.is_boss = w.get("is_boss", false)
		wd.monsters = []
		for m in w.monsters:
			for i in range(m.count):
				var unit = BattleUnit.new()
				unit.max_hp = m.hp
				unit.hp = m.hp
				unit.atk = m.atk
				unit.def = m.def
				wd.monsters.append(unit)
		result.append(wd)
	return result

func tick(delta: float):
	elapsed_time += delta
	if current_wave >= waves.size():
		return

	var wave = waves[current_wave]
	var attack_interval = 1.0 / max(player.atk_speed, 0.1)

	_elapsed_attack += delta
	if _elapsed_attack >= attack_interval:
		_elapsed_attack -= attack_interval
		for monster in wave.monsters:
			if monster.hp > 0:
				var dmg = _calc_damage(player.atk, monster.def, player.crit_rate, player.crit_dmg)
				monster.take_damage(dmg)
				summary.total_damage_dealt += dmg
				wave_damage += dmg
				break

	for monster in wave.monsters:
		if monster.hp > 0:
			var dmg = _calc_damage(monster.atk, player.def, 0, 0)
			player.take_damage(dmg)
			summary.total_damage_taken += dmg
			wave_damage_taken += dmg

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
