extends Control

signal mode_changed(mode: int)

enum Mode { NORMAL, SKILL_INVENTORY, SHOP }

@onready var skill_btn = $SkillBtn
@onready var shop_btn = $ShopBtn
@onready var leaderboard_btn = $LeaderboardBtn

var _current_mode: int = 0

func _ready():
	skill_btn.pressed.connect(_on_skill_pressed)
	shop_btn.pressed.connect(_on_shop_pressed)
	leaderboard_btn.pressed.connect(_on_leaderboard_pressed)

func _on_skill_pressed():
	if _current_mode == Mode.SKILL_INVENTORY:
		_current_mode = Mode.NORMAL
		mode_changed.emit(Mode.NORMAL)
	else:
		_current_mode = Mode.SKILL_INVENTORY
		mode_changed.emit(Mode.SKILL_INVENTORY)
	_update_highlight()

func _on_shop_pressed():
	if _current_mode == Mode.SHOP:
		_current_mode = Mode.NORMAL
		mode_changed.emit(Mode.NORMAL)
	else:
		_current_mode = Mode.SHOP
		mode_changed.emit(Mode.SHOP)
	_update_highlight()

func _on_leaderboard_pressed():
	pass  # Handled by main_ui via direct connection

func set_active_mode(mode: int):
	_current_mode = mode
	_update_highlight()

func _update_highlight():
	skill_btn.modulate = Color.YELLOW if _current_mode == Mode.SKILL_INVENTORY else Color.WHITE
	shop_btn.modulate = Color.YELLOW if _current_mode == Mode.SHOP else Color.WHITE
