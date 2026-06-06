extends Node2D

var player_sprite: ColorRect
var monster_sprites: Array = []
var damage_labels: Array = []

func setup_battle(player_stats: Dictionary, wave_monsters: Array):
	# Draw player as blue rectangle
	player_sprite = ColorRect.new()
	player_sprite.color = Color.BLUE
	player_sprite.size = Vector2(60, 80)
	player_sprite.position = Vector2(100, 300)
	add_child(player_sprite)

	# Draw monsters as red rectangles
	for i in range(wave_monsters.size()):
		var rect = ColorRect.new()
		rect.color = Color.RED
		rect.size = Vector2(50, 60)
		rect.position = Vector2(500 + i * 80, 300)
		add_child(rect)
		monster_sprites.append(rect)

func show_damage(target_pos: Vector2, amount: float, is_crit: bool):
	var label = Label.new()
	label.text = str(int(amount))
	label.add_theme_color_override("font_color", Color.ORANGE if is_crit else Color.WHITE)
	label.position = target_pos
	add_child(label)
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

func clear_all():
	for child in get_children():
		child.queue_free()
	monster_sprites.clear()
