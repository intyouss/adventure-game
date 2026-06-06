extends Node2D

var simulator: BattleSimulator:
	set(value):
		simulator = value
		if simulator:
			simulator.battle_ended.connect(_on_battle_ended)

var player_sprite: ColorRect
var player_hp_bar: ProgressBar
var monster_sprites: Array = []
var monster_hp_bars: Array = []
var damage_labels: Array = []
var _last_monster_count: int = 0
var _last_wave: int = -1

func _ready():
	pass

func _process(_delta):
	if not simulator or simulator.current_wave >= simulator.waves.size():
		return
	var wave = simulator.waves[simulator.current_wave]

	# Respawn visual elements when wave changes
	if simulator.current_wave != _last_wave:
		_last_wave = simulator.current_wave
		_setup_visuals(wave)

	# Update player
	if player_sprite:
		player_sprite.modulate = Color.RED if simulator.player.hp < simulator.player.max_hp * 0.3 else Color.BLUE
	if player_hp_bar:
		player_hp_bar.max_value = simulator.player.max_hp
		player_hp_bar.value = simulator.player.hp

	# Update monster visuals
	for i in range(monster_sprites.size()):
		if i < wave.monsters.size():
			var m = wave.monsters[i]
			monster_sprites[i].visible = m.hp > 0
			if i < monster_hp_bars.size():
				monster_hp_bars[i].visible = m.hp > 0
				monster_hp_bars[i].max_value = m.max_hp
				monster_hp_bars[i].value = m.hp

func _setup_visuals(wave: WaveData):
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
	for i in range(wave.monsters.size()):
		var rect = ColorRect.new()
		rect.color = Color.RED
		rect.size = Vector2(50, 60)
		rect.position = Vector2(500 + i * 80, 300)
		add_child(rect)
		monster_sprites.append(rect)

		var hp_bar = ProgressBar.new()
		hp_bar.size = Vector2(50, 6)
		hp_bar.position = Vector2(500 + i * 80, 362)
		var m = wave.monsters[i]
		hp_bar.max_value = m.max_hp
		hp_bar.value = m.hp
		add_child(hp_bar)
		monster_hp_bars.append(hp_bar)

func show_damage(target_pos: Vector2, amount: float, is_crit: bool):
	var label = Label.new()
	label.text = str(int(amount))
	label.add_theme_color_override("font_color", Color.ORANGE if is_crit else Color.WHITE)
	label.position = target_pos
	add_child(label)
	damage_labels.append(label)
	var tween = create_tween()
	tween.tween_property(label, "position", target_pos + Vector2(0, -50), 0.8)
	tween.tween_callback(label.queue_free)

func show_wave_clear(wave_num: int):
	var label = Label.new()
	label.text = "第 %d 波 清除!" % wave_num
	label.add_theme_color_override("font_color", Color.GREEN)
	label.add_theme_font_size_override("font_size", 32)
	label.position = Vector2(280, 200)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 2.0)
	tween.tween_callback(label.queue_free)

func show_skill_effect(skill_id: String, pos: Vector2):
	var label = Label.new()
	label.text = skill_id
	label.add_theme_color_override("font_color", Color.YELLOW)
	label.position = pos + Vector2(0, -20)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position", pos + Vector2(0, -80), 1.0)
	tween.tween_callback(label.queue_free)

func _on_battle_ended(_summary):
	clear_all()

func clear_all():
	for child in get_children():
		child.queue_free()
	monster_sprites.clear()
	monster_hp_bars.clear()
	damage_labels.clear()
	_last_wave = -1
