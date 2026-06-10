# BattleRenderer - Visual representation of battle (v4 emoji + rounded panel style)
class_name BattleRenderer
extends Control

var simulator: BattleSimulator:
	set(value):
		simulator = value
		if simulator:
			simulator.battle_ended.connect(_on_battle_ended)

var player_avatar: PanelContainer
var player_hp_bar: ProgressBar
var player_name_label: Label
var monster_avatars: Array[PanelContainer] = []
var monster_hp_bars: Array[ProgressBar] = []
var monster_name_labels: Array[Label] = []
var _last_wave: int = -1

func _ready() -> void:
	pass


func _process(_delta: float) -> void:
	if not simulator or simulator.current_wave >= simulator.waves.size():
		return
	var wave: BattleSimulator.WaveData = simulator.waves[simulator.current_wave]

	# Rebuild visuals on wave change
	if simulator.current_wave != _last_wave:
		_last_wave = simulator.current_wave
		_setup_visuals(wave)
		Log.debug("BattleRenderer", "Wave changed", {"wave": simulator.current_wave + 1, "is_boss": wave.is_boss})

	# Update player HP
	if player_hp_bar:
		player_hp_bar.max_value = simulator.player.max_hp
		player_hp_bar.value = simulator.player.hp
		# Low HP warning: change border color to red
		if simulator.player.hp < simulator.player.max_hp * 0.3:
			_set_avatar_border(player_avatar, Color(0.961, 0.400, 0.400))
			if player_name_label:
				player_name_label.text = "⚡低血量"
				player_name_label.add_theme_color_override("font_color", Color(0.898, 0.243, 0.243))
		else:
			_set_avatar_border(player_avatar, ThemeManager.PLAYER_BORDER)
			if player_name_label:
				player_name_label.text = "角色"
				player_name_label.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)

	# Update monster HP
	for i: int in range(monster_avatars.size()):
		if i < wave.monsters.size():
			var m: BattleSimulator.WaveData = wave
			var monster: BattleSimulator.BattleUnit = wave.monsters[i]
			monster_avatars[i].visible = monster.hp > 0
			if i < monster_hp_bars.size():
				monster_hp_bars[i].visible = monster.hp > 0
				monster_hp_bars[i].max_value = monster.max_hp
				monster_hp_bars[i].value = monster.hp


func _setup_visuals(wave: BattleSimulator.WaveData) -> void:
	clear_all()

	# Main container - horizontal layout with player on left, VS, monsters on right
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	add_child(row)

	# Player column
	var player_col := VBoxContainer.new()
	player_col.alignment = BoxContainer.ALIGNMENT_CENTER
	player_col.add_theme_constant_override("separation", 3)
	row.add_child(player_col)

	player_avatar = ThemeManager.make_avatar_panel("🧝", true)
	player_col.add_child(player_avatar)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(52, 6)
	player_hp_bar.max_value = simulator.player.max_hp
	player_hp_bar.value = simulator.player.hp
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = ThemeManager.ACCENT_GREEN
	hp_fill.corner_radius_top_left = 3
	hp_fill.corner_radius_top_right = 3
	hp_fill.corner_radius_bottom_left = 3
	hp_fill.corner_radius_bottom_right = 3
	player_hp_bar.add_theme_stylebox_override("fill", hp_fill)
	player_col.add_child(player_hp_bar)

	player_name_label = Label.new()
	player_name_label.text = "角色"
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name_label.add_theme_font_size_override("font_size", 10)
	player_name_label.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
	player_col.add_child(player_name_label)

	# VS label
	var vs_label := Label.new()
	vs_label.text = "⚔ VS ⚔"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 18)
	vs_label.add_theme_color_override("font_color", ThemeManager.ACCENT_GOLD)
	row.add_child(vs_label)

	# Monster column
	var monster_col := VBoxContainer.new()
	monster_col.alignment = BoxContainer.ALIGNMENT_CENTER
	monster_col.add_theme_constant_override("separation", 3)
	row.add_child(monster_col)

	# Pick emoji for monster based on whether boss
	var monster_emoji: String = "👹" if not wave.is_boss else "👺"
	var monster_name: String = "小怪" if not wave.is_boss else "BOSS"

	var monster_avatar := ThemeManager.make_avatar_panel(monster_emoji, false)
	monster_col.add_child(monster_avatar)
	monster_avatars.append(monster_avatar)

	var mhp := ProgressBar.new()
	mhp.custom_minimum_size = Vector2(52, 6)
	if wave.monsters.size() > 0:
		mhp.max_value = wave.monsters[0].max_hp
		mhp.value = wave.monsters[0].hp
	var mhp_fill := StyleBoxFlat.new()
	mhp_fill.bg_color = Color(0.988, 0.506, 0.506)
	mhp_fill.corner_radius_top_left = 3
	mhp_fill.corner_radius_top_right = 3
	mhp_fill.corner_radius_bottom_left = 3
	mhp_fill.corner_radius_bottom_right = 3
	mhp.add_theme_stylebox_override("fill", mhp_fill)
	monster_col.add_child(mhp)
	monster_hp_bars.append(mhp)

	var mname := Label.new()
	mname.text = monster_name
	mname.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mname.add_theme_font_size_override("font_size", 10)
	mname.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
	monster_col.add_child(mname)
	monster_name_labels.append(mname)


func _set_avatar_border(avatar: PanelContainer, color: Color) -> void:
	if not avatar:
		return
	var sb: StyleBoxFlat = avatar.get_theme_stylebox("panel") as StyleBoxFlat
	if sb:
		sb = sb.duplicate()
		sb.border_color = color
		avatar.add_theme_stylebox_override("panel", sb)


func show_damage(target_pos: Vector2, amount: float, is_crit: bool) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	if is_crit:
		label.add_theme_color_override("font_color", Color.ORANGE)
		label.add_theme_font_size_override("font_size", 20)
	else:
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 14)
	label.position = target_pos
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", target_pos + Vector2(0, -50), 0.8)
	tween.tween_callback(label.queue_free)


func show_wave_clear(wave_num: int) -> void:
	var label := Label.new()
	label.text = "第 %d 关 通过!" % wave_num
	label.add_theme_color_override("font_color", ThemeManager.ACCENT_GREEN)
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.position = Vector2(60, 50)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free)


func show_skill_effect(skill_id: String, pos: Vector2) -> void:
	var label := Label.new()
	label.text = skill_id
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.position = pos + Vector2(0, -20)
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", pos + Vector2(0, -80), 1.0)
	tween.tween_callback(label.queue_free)


func _on_battle_ended(_summary: BattleSimulator.BattleSummary) -> void:
	clear_all()
	Log.info("BattleRenderer", "Battle ended, visuals cleared")


func clear_all() -> void:
	for child: Node in get_children():
		child.queue_free()
	monster_avatars.clear()
	monster_hp_bars.clear()
	monster_name_labels.clear()
	player_avatar = null
	player_hp_bar = null
	player_name_label = null
	_last_wave = -1
