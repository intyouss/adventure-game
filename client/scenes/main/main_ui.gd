extends Control

enum Mode { NORMAL, SKILL_INVENTORY, SHOP }

@onready var hud = $HUD
@onready var battle_area = $BattleArea
@onready var equipment_area = $EquipmentArea
@onready var chest_area = $ChestArea
@onready var bottom_row = $BottomButtonRow
@onready var skill_inventory_panel = $SkillInventoryPanel
@onready var shop_panel = $ShopPanel
@onready var leaderboard_panel = $LeaderboardPanel

@onready var level_label = $HUD/LevelLabel
@onready var exp_bar = $HUD/ExpBar
@onready var gold_label = $HUD/GoldLabel
@onready var ticket_label = $HUD/TicketLabel
@onready var cp_label = $HUD/CPLabel

var _mode: int = 0

func _ready():
	EventBus.login_success.connect(_refresh_hud)
	EventBus.auto_login_success.connect(_refresh_hud)
	bottom_row.mode_changed.connect(_on_mode_changed)
	bottom_row.leaderboard_btn.pressed.connect(_on_leaderboard_toggle)
	_refresh_hud()
	_enter_mode(Mode.NORMAL)

func _on_mode_changed(new_mode: int):
	_enter_mode(new_mode)

func _enter_mode(mode: int):
	_mode = mode
	match mode:
		Mode.NORMAL:
			battle_area.visible = true
			equipment_area.visible = true
			chest_area.visible = true
			skill_inventory_panel.visible = false
			shop_panel.visible = false
		Mode.SKILL_INVENTORY:
			battle_area.visible = true
			equipment_area.visible = false
			chest_area.visible = false
			skill_inventory_panel.visible = true
			shop_panel.visible = false
		Mode.SHOP:
			battle_area.visible = false
			equipment_area.visible = false
			chest_area.visible = false
			skill_inventory_panel.visible = false
			shop_panel.visible = true
	bottom_row.set_active_mode(mode)

func _on_leaderboard_toggle():
	if leaderboard_panel._is_open:
		leaderboard_panel._collapse()
	else:
		leaderboard_panel.open_panel()

func _refresh_hud():
	await PlayerState.load_all()
	var c = PlayerState.character
	if c.is_empty(): return
	level_label.text = "Lv.%d" % c.get("level", 1)
	var exp_to_next = c.get("exp_to_next", 100)
	exp_bar.max_value = max(exp_to_next, 1)
	exp_bar.value = c.get("exp", 0)
	gold_label.text = "💰 %d" % c.get("gold", 0)
	ticket_label.text = "🎫 %d" % c.get("skill_tickets", 0)
	cp_label.text = "CP %.0f" % c.get("cp", 0)

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		print("=== MAIN CLICK at: ", event.position, " btn_idx=", event.button_index)
