# BattleArea - Battle display with integrated combat on main screen (v4)
class_name BattleArea
extends VBoxContainer

@onready var stage_name_label: Label = $StageName
@onready var stage_num_label: Label = $StageNum
@onready var battle_scene: Control = $BattleScene
@onready var battle_hud: Control = $BattleHUD
@onready var wave_label: Label = $BattleHUD/WaveLabel
@onready var damage_label: Label = $BattleHUD/DamageLabel
@onready var time_label: Label = $BattleHUD/TimeLabel
@onready var progress_bar: ProgressBar = $BattleProg
@onready var wave_indicators: HBoxContainer = $WaveIndicators
@onready var skill_slot_container: HBoxContainer = $SkillSlots
@onready var start_btn: Button = $StartBtn

var _slots: Array[PanelContainer] = []
var simulator: BattleSimulator
var renderer: BattleRenderer
var is_battle_active: bool = false
var _stage_id: String = ""

func _ready() -> void:
	theme = ThemeManager.theme
	_style_start_btn()
	_build_wave_indicators(5)
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
	progress_bar.visible = false
	Log.info("BattleArea", "Battle area ready")


func _style_start_btn() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeManager.ACCENT_RED
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	start_btn.add_theme_stylebox_override("normal", sb)
	start_btn.add_theme_color_override("font_color", Color.WHITE)
	start_btn.add_theme_font_size_override("font_size", 15)
	# Progress bar orange
	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = ThemeManager.ACCENT_GOLD
	pb_fill.corner_radius_top_left = 3
	pb_fill.corner_radius_top_right = 3
	pb_fill.corner_radius_bottom_left = 3
	pb_fill.corner_radius_bottom_right = 3
	progress_bar.add_theme_stylebox_override("fill", pb_fill)


func _build_wave_indicators(count: int) -> void:
	for child: Node in wave_indicators.get_children():
		child.queue_free()
	for i: int in range(count):
		var dot := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeManager.BORDER_LIGHT
		sb.corner_radius_top_left = 4
		sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4
		sb.corner_radius_bottom_right = 4
		dot.add_theme_stylebox_override("panel", sb)
		dot.custom_minimum_size = Vector2(24, 8)
		if i == count - 1:
			# BOSS indicator - slightly different
			var lbl := Label.new()
			lbl.text = "👑"
			lbl.add_theme_font_size_override("font_size", 8)
			dot.add_child(lbl)
		wave_indicators.add_child(dot)


func _update_wave_indicators(current_wave: int, total_waves: int) -> void:
	var children := wave_indicators.get_children()
	for i: int in range(children.size()):
		var dot: PanelContainer = children[i]
		var sb: StyleBoxFlat = dot.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb = sb.duplicate()
		else:
			sb = StyleBoxFlat.new()
			sb.corner_radius_top_left = 4
			sb.corner_radius_top_right = 4
			sb.corner_radius_bottom_left = 4
			sb.corner_radius_bottom_right = 4
		if i < current_wave:
			sb.bg_color = ThemeManager.ACCENT_GREEN
		elif i == current_wave:
			if i == total_waves - 1:
				sb.bg_color = ThemeManager.ACCENT_RED
			else:
				sb.bg_color = ThemeManager.ACCENT_GOLD
		else:
			sb.bg_color = ThemeManager.BORDER_LIGHT
		dot.add_theme_stylebox_override("panel", sb)


func _setup_innate_slot() -> void:
	# Clear existing slots
	for child: Node in skill_slot_container.get_children():
		child.queue_free()
	_slots.clear()
	# Slot 0: innate skill (🔥)
	var innate := ThemeManager.make_skill_slot("🔥", "innate")
	skill_slot_container.add_child(innate)
	_slots.append(innate)
	# Slots 1-4: equipped or empty
	for i: int in range(4):
		var slot := ThemeManager.make_skill_slot("+", "empty")
		skill_slot_container.add_child(slot)
		_slots.append(slot)


func _chapter_name(chapter: int) -> String:
	var names: Dictionary = {
		1: "第一章", 2: "第二章", 3: "第三章", 4: "第四章", 5: "第五章",
		6: "第六章", 7: "第七章", 8: "第八章", 9: "第九章", 10: "第十章",
	}
	return names.get(chapter, "第%d章" % chapter)


func _refresh_stage_title() -> void:
	var chapter: int = PlayerState.stage_chapter
	var level: int = PlayerState.stage_level
	stage_name_label.text = _chapter_name(chapter)
	stage_num_label.text = "%d-%d" % [chapter, level]
	Log.debug("BattleArea", "Stage title refreshed", {"chapter": chapter, "level": level})


func _setup_idle_display() -> void:
	for child: Node in battle_scene.get_children():
		child.queue_free()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	battle_scene.add_child(row)

	# Player avatar (emoji + rounded panel)
	var player_col := VBoxContainer.new()
	player_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(player_col)
	var player_avatar := ThemeManager.make_avatar_panel("🧝", true)
	player_col.add_child(player_avatar)
	var player_hp := ProgressBar.new()
	player_hp.custom_minimum_size = Vector2(52, 6)
	player_hp.max_value = 100
	player_hp.value = 80
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = ThemeManager.ACCENT_GREEN
	hp_fill.corner_radius_top_left = 3
	hp_fill.corner_radius_top_right = 3
	hp_fill.corner_radius_bottom_left = 3
	hp_fill.corner_radius_bottom_right = 3
	player_hp.add_theme_stylebox_override("fill", hp_fill)
	player_col.add_child(player_hp)
	var player_name := Label.new()
	player_name.text = "角色"
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name.add_theme_font_size_override("font_size", 10)
	player_name.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
	player_col.add_child(player_name)

	# VS label
	var vs_label := Label.new()
	vs_label.text = "⚔ VS ⚔"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 18)
	vs_label.add_theme_color_override("font_color", ThemeManager.ACCENT_GOLD)
	row.add_child(vs_label)

	# Monster avatar
	var monster_col := VBoxContainer.new()
	monster_col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(monster_col)
	var monster_avatar := ThemeManager.make_avatar_panel("👹", false)
	monster_col.add_child(monster_avatar)
	var monster_hp := ProgressBar.new()
	monster_hp.custom_minimum_size = Vector2(52, 6)
	monster_hp.max_value = 100
	monster_hp.value = 60
	var mhp_fill := StyleBoxFlat.new()
	mhp_fill.bg_color = Color(0.988, 0.506, 0.506)
	mhp_fill.corner_radius_top_left = 3
	mhp_fill.corner_radius_top_right = 3
	mhp_fill.corner_radius_bottom_left = 3
	mhp_fill.corner_radius_bottom_right = 3
	monster_hp.add_theme_stylebox_override("fill", mhp_fill)
	monster_col.add_child(monster_hp)
	var monster_name := Label.new()
	monster_name.text = "怪物"
	monster_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	monster_name.add_theme_font_size_override("font_size", 10)
	monster_name.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
	monster_col.add_child(monster_name)

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
	progress_bar.visible = true
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
	for child: Node in battle_scene.get_children():
		child.queue_free()
	simulator = BattleSimulator.new()
	simulator.start_battle(config.get("config", config), PlayerState.character.get("stats", {}))
	add_child(simulator)
	renderer = BattleRenderer.new()
	renderer.simulator = simulator
	battle_scene.add_child(renderer)
	simulator.battle_ended.connect(_on_battle_finished)
	EventBus.battle_started.emit(_stage_id)
	is_battle_active = true
	# Update wave indicators
	var wave_count: int = simulator.waves.size()
	_build_wave_indicators(wave_count)


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
	Log.info("BattleArea", "Plan A verification", {"passed": passed})
	if not passed:
		_show_error("战斗校验失败: " + result.get("reason", "未知错误"))


func _on_plan_b(result: Dictionary) -> void:
	var passed: bool = result.get("passed", false)
	Log.info("BattleArea", "Plan B verification", {"passed": passed})
	if not passed:
		_show_error("服务端验证未通过，战斗结果无效")


func _on_settled(data: Dictionary) -> void:
	Log.info("BattleArea", "Battle settled", {"rewards": data.get("rewards", {})})
	if data.has("rewards"):
		EventBus.reward_received.emit(data.rewards)
	await PlayerState.load_all()
	EventBus.inventory_changed.emit()
	_cleanup_battle()
	start_btn.visible = true
	battle_hud.visible = false
	progress_bar.visible = false
	_setup_idle_display()
	_refresh_stage_title()


func _on_error(payload: Dictionary) -> void:
	Log.error("BattleArea", "Battle error", {"msg": payload.get("msg", "?")})
	_show_error(payload.get("msg", "未知服务端错误"))
	_cleanup_battle()
	start_btn.visible = true
	battle_hud.visible = false
	progress_bar.visible = false


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
	wave_label.text = "第 %d/%d 关 %s" % [simulator.current_wave + 1, total_waves, "[BOSS]" if wave.is_boss else ""]
	damage_label.text = "💥伤害: %.0f" % simulator.summary.total_damage_dealt
	time_label.text = "⏱%.1fs" % simulator.elapsed_time
	progress_bar.value = float(simulator.current_wave) / float(max(total_waves, 1))
	_update_wave_indicators(simulator.current_wave, total_waves)


# ── Skill Slots ──────────────────────────────────────

func _refresh_skill_slots() -> void:
	var equipped: Array = PlayerState.skill_equipped
	Log.debug("BattleArea", "Refreshing skill slots", {"equipped_count": equipped.size()})
	# Slots[0] = innate, Slots[1-4] = equipped
	for i in range(1, 5):
		if i >= _slots.size():
			break
		var slot: PanelContainer = _slots[i]
		if i - 1 < equipped.size() and equipped[i - 1] != null and equipped[i - 1] != "":
			var skill_name: String = _find_skill_name(str(equipped[i - 1]))
			var emoji: String = _find_skill_emoji(str(equipped[i - 1]))
			# Replace the label text inside the slot
			if slot.get_child_count() > 0 and slot.get_child(0) is Label:
				slot.get_child(0).text = emoji if emoji != "" else skill_name.left(1)
			# Restyle as equipped
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.922, 0.973, 1.0)
			sb.border_color = Color(0.565, 0.804, 0.957)
			sb.border_width_bottom = 2
			sb.border_width_top = 2
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.corner_radius_top_left = 10
			sb.corner_radius_top_right = 10
			sb.corner_radius_bottom_left = 10
			sb.corner_radius_bottom_right = 10
			slot.add_theme_stylebox_override("panel", sb)
		else:
			if slot.get_child_count() > 0 and slot.get_child(0) is Label:
				slot.get_child(0).text = "+"
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.929, 0.949, 0.969)
			sb.border_color = ThemeManager.BORDER
			sb.border_width_bottom = 2
			sb.border_width_top = 2
			sb.border_width_left = 2
			sb.border_width_right = 2
			sb.corner_radius_top_left = 10
			sb.corner_radius_top_right = 10
			sb.corner_radius_bottom_left = 10
			sb.corner_radius_bottom_right = 10
			slot.add_theme_stylebox_override("panel", sb)


func _find_skill_name(skill_id: String) -> String:
	for skill: Dictionary in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "")
	return ""


func _find_skill_emoji(skill_id: String) -> String:
	for skill: Dictionary in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("emoji", skill.get("icon", ""))
	return ""
