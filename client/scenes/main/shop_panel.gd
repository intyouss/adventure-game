extends Control

@onready var grid = $Grid
@onready var close_btn = $CloseBtn

func _ready():
	close_btn.pressed.connect(_on_close)
	_setup_shops()

func _setup_shops():
	var shops = [
		{"name": "技能商店", "icon": "📜", "available": true},
		{"name": "装备商店", "icon": "⚔️", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
	]
	for shop in shops:
		var btn = Button.new()
		btn.text = "%s\n%s" % [shop.icon, shop.name]
		btn.disabled = not shop.available
		if shop.available:
			btn.pressed.connect(_open_skill_shop)
		grid.add_child(btn)
	grid.columns = 2

func _open_skill_shop():
	# Load the existing skill shop UI as a popup
	var skill_scene = load("res://scenes/skill/skill_ui.gd").new()
	add_child(skill_scene)

func _on_close():
	hide()
