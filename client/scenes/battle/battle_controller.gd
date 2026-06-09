# BattleController - Standalone battle scene (kept for reference/testing)
# Battle is now integrated into BattleArea on main screen
class_name BattleController
extends Node

@onready var progress_bar: ProgressBar = $ProgressBar
@onready var wave_label: Label = $WaveLabel
@onready var damage_label: Label = $DamageLabel
@onready var time_label: Label = $TimeLabel

var simulator: BattleSimulator
var renderer: BattleRenderer
var is_battle_active: bool = false
var _stage_id: String = ""

signal battle_completed(summary: Dictionary)

func _ready() -> void:
	NetworkManager.ws_message_received.connect(_on_ws_message)
	Log.info("BattleController", "Battle controller ready (standalone mode)")

func start_stage(stage_id: String) -> void:
	_stage_id = stage_id
	Log.info("BattleController", "Starting stage", {"stage_id": stage_id})
	NetworkManager.connect_ws()
	await NetworkManager.ws_connected
	NetworkManager.send_ws_message("request_stage_config", {"stage_id": stage_id})

func _on_ws_message(type: String, payload: Dictionary) -> void:
	match type:
		"stage_config":
			_on_stage_config(payload)
		"plan_a_result":
			_on_plan_a(payload)
		"plan_b_result":
			_on_plan_b(payload)
		"battle_settled":
			_on_settled(payload)
		"error":
			_on_error(payload)

func _on_stage_config(config: Dictionary) -> void:
	Log.info("BattleController", "Stage config received", {"stage_id": config.get("stage_id", "?")})
	simulator = BattleSimulator.new()
	simulator.start_battle(config.get("config", config), PlayerState.character.get("stats", {}))
	add_child(simulator)

	renderer = BattleRenderer.new()
	renderer.simulator = simulator
	add_child(renderer)

	simulator.battle_ended.connect(_on_battle_finished)
	EventBus.battle_started.emit(_stage_id)
	is_battle_active = true

func _on_battle_finished(summary: BattleSimulator.BattleSummary) -> void:
	Log.info("BattleController", "Battle finished", {
		"stage_id": summary.stage_id,
		"damage_dealt": summary.total_damage_dealt,
		"clear_time_ms": summary.clear_time_ms,
	})
	is_battle_active = false
	NetworkManager.send_ws_message("battle_summary", summary.to_dict())

func _on_plan_a(result: Dictionary) -> void:
	var passed: bool = result.get("passed", false)
	Log.info("BattleController", "Plan A verification", {"passed": passed, "reason": result.get("reason", "")})
	if not passed:
		_show_error("战斗校验失败: " + result.get("reason", "未知错误"))

func _on_plan_b(result: Dictionary) -> void:
	var passed: bool = result.get("passed", false)
	Log.info("BattleController", "Plan B verification", {"passed": passed})
	if not passed:
		_show_error("服务端验证未通过，战斗结果无效")

func _on_settled(data: Dictionary) -> void:
	Log.info("BattleController", "Battle settled", {"rewards": data.get("rewards", {})})
	PlayerState.update_from_server(data)
	if data.has("rewards"):
		EventBus.reward_received.emit(data.rewards)
	battle_completed.emit(data.get("summary", {}))

func _on_error(payload: Dictionary) -> void:
	Log.error("BattleController", "Battle error", {"msg": payload.get("msg", "?")})
	_show_error(payload.get("msg", "未知服务端错误"))

func _show_error(msg: String) -> void:
	var popup := AcceptDialog.new()
	popup.title = "提示"
	popup.dialog_text = msg
	add_child(popup)
	popup.popup_centered()

func _process(delta: float) -> void:
	if not is_battle_active:
		return
	simulator.tick(delta)
	_update_ui()

func _update_ui() -> void:
	if not simulator or simulator.current_wave >= simulator.waves.size():
		return
	var wave: BattleSimulator.WaveData = simulator.waves[simulator.current_wave]
	var total_waves: int = simulator.waves.size()
	wave_label.text = "第 %d/%d 泡 %s" % [simulator.current_wave + 1, total_waves, "[BOSS]" if wave.is_boss else ""]
	damage_label.text = "伤害: %.0f" % simulator.summary.total_damage_dealt
	time_label.text = "%.1fs" % simulator.elapsed_time
	progress_bar.value = float(simulator.current_wave) / float(max(total_waves, 1))
