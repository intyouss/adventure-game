extends Node

@onready var progress_bar = $ProgressBar
@onready var wave_label = $WaveLabel
@onready var damage_label = $DamageLabel
@onready var time_label = $TimeLabel

var simulator: BattleSimulator
var is_battle_active: bool = false
var _stage_id: String = ""

signal battle_completed(summary: Dictionary)

func start_stage(stage_id: String):
	_stage_id = stage_id
	var res = await NetworkManager.request("GET", "/api/stage/start?stage_id=" + stage_id)
	if res.code != 0:
		print("无法进入关卡: ", res.msg)
		return

	var cfg = res.data
	simulator = BattleSimulator.new()
	add_child(simulator)
	simulator.battle_ended.connect(_on_battle_ended)

	var pstats = PlayerState.character.get("stats", {})
	simulator.start_battle(cfg, pstats)
	is_battle_active = true
	EventBus.battle_started.emit(stage_id)

func _process(delta):
	if not is_battle_active:
		return
	simulator.tick(delta)
	_update_ui()

func _update_ui():
	if not simulator or simulator.current_wave >= simulator.waves.size():
		return
	var wave = simulator.waves[simulator.current_wave]
	var total_waves = simulator.waves.size()
	wave_label.text = "第 %d/%d 波 %s" % [simulator.current_wave + 1, total_waves, "[BOSS]" if wave.is_boss else ""]
	damage_label.text = "伤害: %.0f" % simulator.summary.total_damage_dealt
	time_label.text = "%.1fs" % (simulator.elapsed_time)
	progress_bar.value = float(simulator.current_wave) / float(max(total_waves, 1))

func _on_battle_ended(summary):
	is_battle_active = false
	wave_label.text = "战斗结束!"
	battle_completed.emit(summary.to_dict())

	# Submit to server
	NetworkManager.connect_ws()
	await NetworkManager.ws_connected
	NetworkManager.send_ws_message("battle_summary", summary.to_dict())
