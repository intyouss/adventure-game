# BattleRenderer - Visual representation of battle (character + monster + effects)
class_name BattleRenderer
extends Node2D

var simulator: BattleSimulator:
	set(value):
		simulator = value
		if simulator:
			simulator.battle_ended.connect(_on_battle_ended)

var player_sprite: ColorRect
var player_hp_bar: ProgressBar
var monster_sprites: Array[ColorRect] = []
var monster_hp_bars: Array[ProgressBar] = []
var _last_wave: int = -1

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if not simulator or simulator.current_wave >= simulator.waves.size():
		return
	var wave: BattleSimulator.WaveData = simulator.waves[simulator.current_wave]

	# Respawn visual elements when wave changes
	if simulator.current_wave != _last_wave:
		_last_wave = simulator.current_wave
		_setup_visuals(wave)
		Log.debug("BattleRenderer", "Wave changed", {"wave": simulator.current_wave + 1, "is_boss": wave.is_boss})

	# Update player
	if player_sprite:
		player_sprite.modulate = Color.RED if simulator.player.hp < simulator.player.max_hp * 0.3 else Color.BLUE
	if player_hp_bar:
		player_hp_bar.max_value = simulator.player.max_hp
		player_hp_bar.value = simulator.player.hp

	# Update monster visuals
	for i: int in range(monster_sprites.size()):
		if i < wave.monsters.size():
			var m: BattleSimulator.BattleUnit = wave.monsters[i]
			monster_sprites[i].visible = m.hp > 0
			if i < monster_hp_bars.size():
				monster_hp_bars[i].visible = m.hp > 0
				monster_hp_bars[i].max_value = m.max_hp
				monster_hp_bars[i].value = m.hp

func _setup_visuals(wave: BattleSimulator.WaveData) -> void:
	clear_all()

	# Draw player as blue rectangle with HP bar
	player_sprite = ColorRect.new()
	player_sprite.color = Color.BLUE
	player_sprite.size = Vector2(60, 80)
	player_sprite.position = Vector2(100, 300)
	add_child(player_sprite)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.size = Vector2(60, 8)
	player_hp_bar.position = Vector2(100, 382)
	player_hp_bar.max_value = simulator.player.max_hp
	player_hp_bar.value = simulator.player.hp
	add_child(player_hp_bar)

	# Draw monsters as red rectangles with HP bars
	for i: int in range(wave.monsters.size()):
		var rect := ColorRect.new()
		rect.color = Color.RED
		rect.size = Vector2(50, 60)
		rect.position = Vector2(500 + i * 80, 300)
		add_child(rect)
		monster_sprites.append(rect)

		var hp_bar := ProgressBar.new()
		hp_bar.size = Vector2(50, 6)
		hp_bar.position = Vector2(500 + i * 80, 362)
		var m: BattleSimulator.BattleUnit = wave.monsters[i]
		hp_bar.max_value = m.max_hp
		hp_bar.value = m.hp
		add_child(hp_bar)
		monster_hp_bars.append(hp_bar)

func show_damage(target_pos: Vector2, amount: float, is_crit: bool) -> void:
	var label := Label.new()
	label.text = str(int(amount))
	label.add_theme_color_override("font_color", Color.ORANGE if is_crit else Color.WHITE)
	label.position = target_pos
	add_child(label)
	var tween := create_tween()
	tween.tween_property(label, "position", target_pos + Vector2(0, -50), 0.8)
	tween.tween_callback(label.queue_free)

func show_wave_clear(wave_num: int) -> void:
	var label := Label.new()
	label.text = "第 %d 泡 清除!" % wave_num
	label.add_theme_color_override("font_color", Color.GREEN)
	label.add_theme_font_size_override("font_size", 32)
	label.position = Vector2(280, 200)
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
	monster_sprites.clear()
	monster_hp_bars.clear()
	_last_wave = -1
