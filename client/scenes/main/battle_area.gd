# BattleArea - Battle display with integrated combat on main screen
class_name BattleArea
extends Control

@onready var stage_name_label: Label = $StageName
@onready var battle_scene: Control = $BattleScene
@onready var battle_hud: Control = $BattleHUD
@onready var wave_label: Label = $BattleHUD/WaveLabel
@onready var damage_label: Label = $BattleHUD/DamageLabel
@onready var time_label: Label = $BattleHUD/TimeLabel
@onready var progress_bar: ProgressBar = $BattleHUD/ProgressBar
@onready var skill_slot_0: Button = $SkillSlots/Slot0
@onready var skill_slot_1: Button = $SkillSlots/Slot1
@onready var skill_slot_2: Button = $SkillSlots/Slot2
@onready var skill_slot_3: Button = $SkillSlots/Slot3
@onready var skill_slot_4: Button = $SkillSlots/Slot4
@onready var start_btn: Button = $StartBtn

var _slots: Array[Button] = []
var simulator: BattleSimulator
var renderer: BattleRenderer
var is_battle_active: bool = false
var _stage_id: String = ""

func _ready() -> void:
	_slots = [skill_slot_0, skill_slot_1, skill_slot_2, skill_slot_3, skill_slot_4]
	_setup_innate_slot()
	EventBus.skill_updated.connect(_refresh_skill_slots)
	EventBus.login_success.connect(_refresh_stage_title)
	EventBus.auto_login_success.connect(_refresh_stage_title)
	NetworkManager.ws_message_received.connect(_on_ws_message)
	start_btn.pressed.connect(_on_start_pressed)
	_refresh_skill_slots()
	_refresh_stage_title()
	_setup_idle_display()
	battle_hud.visible = false
	Log.info("BattleArea", "Battle area ready")

func _setup_innate_slot() -> void:
	skill_slot_0.disabled = true
	skill_slot_0.modulate = Color(1.0, 0.75, 0.0)
	skill_slot_0.text = "🔥"

func _chapter_name(chapter: int) -> String:
	var names: Dictionary = {
		1: "第一章", 2: "第二章", 3: "第三章", 4: "第四章", 5: "第五章",
		6: "第六章", 7: "第七章", 8: "第八章", 9: "第九章", 10: "第十章",
	}
	return names.get(chapter, "第%d章" % chapter)

func _refresh_stage_title() -> void:
	var chapter: int = PlayerState.stage_chapter
	var level: int = PlayerState.stage_level
	stage_name_label.text = "%s %d-%d" % [_chapter_name(chapter), chapter, level]
	Log.debug("BattleArea", "Stage title refreshed", {"chapter": chapter, "level": level})

func _setup_idle_display() -> void:
	# Show idle battle scene with character + monster placeholders
	for child: Node in battle_scene.get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	battle_scene.add_child(row)

	var char_label := Label.new()
	char_label.text = "🧝 角色"
	char_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	char_label.add_theme_font_size_override("font_size", 20)
	row.add_child(char_label)

	var vs_label := Label.new()
	vs_label.text = "⚔ VS ⚔"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vs_label.add_theme_font_size_override("font_size", 18)
	row.add_child(vs_label)

	var mon_label := Label.new()
	mon_label.text = "👹 怪物"
	mon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mon_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mon_label.add_theme_font_size_override("font_size", 20)
	row.add_child(mon_label)

# ── Battle Start ──────────────────────────────────────

func _on_start_pressed() -> void:
	if is_battle_active:
		return
	var chapter: int = PlayerState.stage_chapter
	var level: int = PlayerState.stage_level
	_stage_id = "%d-%d" % [chapter, level]
	Log.info("BattleArea", "Starting battle", {"stage_id": _stage_id})
	start_btn.visible = false
	battle_hud.visible = true
	NetworkManager.connect_ws()
	await NetworkManager.ws_connected
	NetworkManager.send_ws_message("request_stage_config", {"stage_id": _stage_id})

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
	Log.info("BattleArea", "Stage config received", {"stage_id": config.get("stage_id", "?")})
	# Clear idle display
	for child: Node in battle_scene.get_children():
		child.queue_free()
	# Create simulator
	simulator = BattleSimulator.new()
	simulator.start_battle(config.get("config", config), PlayerState.character.get("stats", {}))
	add_child(simulator)
	# Create renderer inside battle_scene
	renderer = BattleRenderer.new()
	renderer.simulator = simulator
	battle_scene.add_child(renderer)
	simulator.battle_ended.connect(_on_battle_finished)
	EventBus.battle_started.emit(_stage_id)
	is_battle_active = true

func _on_battle_finished(summary: BattleSimulator.BattleSummary) -> void:
	Log.info("BattleArea", "Battle finished", {
		"stage_id": summary.stage_id,
		"damage_dealt": summary.total_damage_dealt,
		"clear_time_ms": summary.clear_time_ms,
	})
	is_battle_active = false
	NetworkManager.send_ws_message("battle_summary", summary.to_dict())

func _on_plan_a(result: Dictionary) -> void:
	var passed: bool = result.get("passed", false)
	Log.info("BattleArea", "Plan A verification", {"passed": passed, "reason": result.get("reason", "")})
	if not passed:
		_show_error("战斗校验失败: " + result.get("reason", "未知错误"))

func _on_plan_b(result: Dictionary) -> void:
	var passed: bool = result.get("passed", false)
	Log.info("BattleArea", "Plan B verification", {"passed": passed})
	if not passed:
		_show_error("服务端验证未通过，战斗结果无效")

func _on_settled(data: Dictionary) -> void:
	Log.info("BattleArea", "Battle settled", {"rewards": data.get("rewards", {})})
	PlayerState.update_from_server(data)
	if data.has("rewards"):
		EventBus.reward_received.emit(data.rewards)
	# Reset UI for next battle
	_cleanup_battle()
	start_btn.visible = true
	battle_hud.visible = false
	_setup_idle_display()
	_refresh_stage_title()

func _on_error(payload: Dictionary) -> void:
	Log.error("BattleArea", "Battle error", {"msg": payload.get("msg", "?")})
	_show_error(payload.get("msg", "未知服务端错误"))
	_cleanup_battle()
	start_btn.visible = true
	battle_hud.visible = false

func _cleanup_battle() -> void:
	if renderer:
		renderer.queue_free()
		renderer = null
	if simulator:
		simulator.queue_free()
		simulator = null

func _show_error(msg: String) -> void:
	var popup := AcceptDialog.new()
	popup.title = "提示"
	popup.dialog_text = msg
	add_child(popup)
	popup.popup_centered()

# ── Process ───────────────────────────────────────────

func _process(delta: float) -> void:
	if not is_battle_active or not simulator:
		return
	simulator.tick(delta)
	_update_battle_hud()

func _update_battle_hud() -> void:
	if not simulator or simulator.current_wave >= simulator.waves.size():
		return
	var wave: BattleSimulator.WaveData = simulator.waves[simulator.current_wave]
	var total_waves: int = simulator.waves.size()
	wave_label.text = "第 %d/%d 泡 %s" % [simulator.current_wave + 1, total_waves, "[BOSS]" if wave.is_boss else ""]
	damage_label.text = "伤害: %.0f" % simulator.summary.total_damage_dealt
	time_label.text = "%.1fs" % simulator.elapsed_time
	progress_bar.value = float(simulator.current_wave) / float(max(total_waves, 1))

# ── Skill Slots ──────────────────────────────────────

func _refresh_skill_slots() -> void:
	var equipped: Array = PlayerState.skill_equipped
	Log.debug("BattleArea", "Refreshing skill slots", {"equipped_count": equipped.size()})
	for i in range(1, 5):
		var slot: Button = _slots[i]
		if i - 1 < equipped.size() and equipped[i - 1] != null and equipped[i - 1] != "":
			var skill_name: String = _find_skill_name(str(equipped[i - 1]))
			slot.text = skill_name if skill_name != "" else "?"
			slot.modulate = Color.WHITE
		else:
			slot.text = "+"
			slot.modulate = Color(0.3, 0.3, 0.3)

func _find_skill_name(skill_id: String) -> String:
	for skill: Dictionary in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "")
	return ""
