# MainUI - Main game interface controller with 4-Tab navigation
class_name MainUI
extends Control

enum ViewMode { BATTLE, SKILL_INVENTORY, SHOP }

@onready var hud: Control = $HUD
@onready var battle_area: Control = $ContentArea/BattleArea
@onready var equipment_area: Control = $ContentArea/EquipmentArea
@onready var chest_area: Control = $ContentArea/ChestArea
@onready var bottom_row: Control = $BottomButtonRow
@onready var skill_inventory_panel: Control = $ContentArea/SkillInventoryPanel
@onready var shop_panel: Control = $ContentArea/ShopPanel
@onready var leaderboard_panel: Control = $LeaderboardPanel

@onready var level_label: Label = $HUD/LevelLabel
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var gold_label: Label = $HUD/GoldLabel
@onready var ticket_label: Label = $HUD/TicketLabel
@onready var cp_label: Label = $HUD/CPLabel

var _view_mode: int = ViewMode.BATTLE
var _refreshing: bool = false

func _ready() -> void:
	EventBus.login_success.connect(_refresh_hud)
	EventBus.auto_login_success.connect(_refresh_hud)
	EventBus.inventory_changed.connect(_refresh_hud)
	EventBus.skill_updated.connect(_refresh_hud)
	bottom_row.tab_pressed.connect(_on_tab_pressed)
	_enter_view(ViewMode.BATTLE)
	_refresh_hud_async()
	Log.info("MainUI", "Main scene ready")

func _refresh_hud_async() -> void:
	await _refresh_hud()

func _on_tab_pressed(tab: int) -> void:
	match tab:
		0:  # BATTLE
			_enter_view(ViewMode.BATTLE)
		1:  # SKILL
			_enter_view(ViewMode.SKILL_INVENTORY)
		2:  # SHOP
			_enter_view(ViewMode.SHOP)
		3:  # LEADERBOARD
			_toggle_leaderboard()

func _enter_view(mode: int) -> void:
	_view_mode = mode
	Log.debug("MainUI", "View changed", {"mode": ViewMode.keys()[mode] if mode < ViewMode.size() else "?"})
	# Close leaderboard when switching views
	if leaderboard_panel._is_open:
		leaderboard_panel._collapse()
	match mode:
		ViewMode.BATTLE:
			battle_area.visible = true
			equipment_area.visible = true
			chest_area.visible = true
			skill_inventory_panel.visible = false
			shop_panel.visible = false
			_refresh_hud()
		ViewMode.SKILL_INVENTORY:
			battle_area.visible = false
			equipment_area.visible = false
			chest_area.visible = false
			skill_inventory_panel.visible = true
			shop_panel.visible = false
		ViewMode.SHOP:
			battle_area.visible = false
			equipment_area.visible = false
			chest_area.visible = false
			skill_inventory_panel.visible = false
			shop_panel.visible = true

func _toggle_leaderboard() -> void:
	if leaderboard_panel._is_open:
		leaderboard_panel._collapse()
	else:
		leaderboard_panel.open_panel()
	Log.debug("MainUI", "Leaderboard toggled", {"is_open": leaderboard_panel._is_open})

func _refresh_hud() -> void:
	if _refreshing:
		Log.debug("MainUI", "HUD refresh skipped (already refreshing)")
		return
	_refreshing = true
	Log.debug("MainUI", "Refreshing HUD...")
	await PlayerState.load_all()
	_refreshing = false
	var c: Dictionary = PlayerState.character
	if c.is_empty():
		Log.warn("MainUI", "HUD refresh: character data empty")
		return
	level_label.text = "Lv.%d" % c.get("level", 1)
	var exp_to_next: int = c.get("exp_to_next", 100)
	exp_bar.max_value = max(exp_to_next, 1)
	exp_bar.value = c.get("exp", 0)
	gold_label.text = "💰 %d" % c.get("gold", 0)
	ticket_label.text = "🎟 %d" % c.get("skill_tickets", 0)
	var cp_value: float = c.get("cp", 0.0)
	cp_label.text = "⚔ CP %.0f" % cp_value
	Log.debug("MainUI", "HUD refreshed", {"level": c.get("level", 1), "gold": c.get("gold", 0), "cp": cp_value})
