# MainUI - Main game interface controller with 4-Tab navigation (v4)
class_name MainUI
extends Control

enum ViewMode { BATTLE, SKILL_INVENTORY, SHOP }

@onready var hud: Control = $HUD
@onready var battle_area: Control = $ContentArea/ContentVBox/BattleArea
@onready var equipment_area: Control = $ContentArea/ContentVBox/EquipmentArea
@onready var chest_area: Control = $ContentArea/ContentVBox/ChestArea
@onready var bottom_row: Control = $BottomButtonRow
@onready var skill_inventory_panel: Control = $ContentArea/ContentVBox/SkillInventoryPanel
@onready var shop_panel: Control = $ContentArea/ContentVBox/ShopPanel
@onready var leaderboard_panel: Control = $LeaderboardPanel
@onready var compare_popup: ColorRect = $ComparePopup

@onready var level_label: Label = $HUD/LevelBadge/LevelLabel
@onready var level_badge: PanelContainer = $HUD/LevelBadge
@onready var exp_bar: ProgressBar = $HUD/ExpBar
@onready var gold_label: Label = $HUD/ResourceRow/GoldLabel
@onready var ticket_label: Label = $HUD/ResourceRow/TicketLabel
@onready var cp_label: Label = $HUD/ResourceRow/CPLabel

var _view_mode: int = ViewMode.BATTLE
var _refreshing: bool = false

func _ready() -> void:
	theme = ThemeManager.theme
	_style_hud()
	_style_compare_popup()
	EventBus.login_success.connect(_refresh_hud)
	EventBus.auto_login_success.connect(_refresh_hud)
	EventBus.inventory_changed.connect(_refresh_hud)
	EventBus.skill_updated.connect(_refresh_hud)
	bottom_row.tab_pressed.connect(_on_tab_pressed)
	_enter_view(ViewMode.BATTLE)
	_refresh_hud_async()
	compare_popup.visible = false
	Log.info("MainUI", "Main scene ready")


func _style_hud() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeManager.ACCENT_RED
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	level_badge.add_theme_stylebox_override("panel", sb)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = ThemeManager.ACCENT_GREEN
	pb_fill.corner_radius_top_left = 4
	pb_fill.corner_radius_top_right = 4
	pb_fill.corner_radius_bottom_left = 4
	pb_fill.corner_radius_bottom_right = 4
	exp_bar.add_theme_stylebox_override("fill", pb_fill)


func _style_compare_popup() -> void:
	var popup_panel: PanelContainer = $ComparePopup/PopupPanel
	if popup_panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeManager.BG_PANEL
		sb.border_color = ThemeManager.ACCENT
		sb.border_width_bottom = 2
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		sb.content_margin_top = 16
		sb.content_margin_bottom = 16
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		popup_panel.add_theme_stylebox_override("panel", sb)

	var title: Label = $ComparePopup/PopupPanel/VBox/Title
	if title:
		title.add_theme_color_override("font_color", ThemeManager.ACCENT)

	var keep_btn: Button = $ComparePopup/PopupPanel/VBox/BtnRow/KeepBtn
	if keep_btn:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.929, 0.949, 0.969)
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		keep_btn.add_theme_stylebox_override("normal", sb)
		keep_btn.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)

	var replace_btn: Button = $ComparePopup/PopupPanel/VBox/BtnRow/ReplaceBtn
	if replace_btn:
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeManager.ACCENT_RED
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		replace_btn.add_theme_stylebox_override("normal", sb)
		replace_btn.add_theme_color_override("font_color", Color.WHITE)


func _on_tab_pressed(tab: int) -> void:
	match tab:
		0: _enter_view(ViewMode.BATTLE)
		1: _enter_view(ViewMode.SKILL_INVENTORY)
		2: _enter_view(ViewMode.SHOP)
		3: _toggle_leaderboard()


func _enter_view(mode: int) -> void:
	_view_mode = mode
	if leaderboard_panel._is_open:
		leaderboard_panel._collapse()
	battle_area.visible = false
	equipment_area.visible = false
	chest_area.visible = false
	skill_inventory_panel.visible = false
	shop_panel.visible = false
	match mode:
		ViewMode.BATTLE:
			battle_area.visible = true
			equipment_area.visible = true
			chest_area.visible = true
			_refresh_hud()
		ViewMode.SKILL_INVENTORY:
			skill_inventory_panel.visible = true
			skill_inventory_panel._refresh()
		ViewMode.SHOP:
			shop_panel.visible = true
			shop_panel._refresh_gacha()
	Log.debug("MainUI", "View changed", {"mode": ViewMode.keys()[mode] if mode < ViewMode.size() else "?"})


func _toggle_leaderboard() -> void:
	if leaderboard_panel._is_open:
		leaderboard_panel._collapse()
	else:
		leaderboard_panel.open_panel()
	Log.debug("MainUI", "Leaderboard toggled", {"is_open": leaderboard_panel._is_open})


func _refresh_hud() -> void:
	if _refreshing:
		return
	_refreshing = true
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
	gold_label.text = "💰%s" % _format_num(c.get("gold", 0))
	ticket_label.text = "🎟%d" % c.get("skill_tickets", 0)
	var cp_value: float = c.get("cp", 0.0)
	cp_label.text = "⚔%s" % _format_num(int(cp_value))
	Log.debug("MainUI", "HUD refreshed", {"level": c.get("level", 1), "gold": c.get("gold", 0), "cp": cp_value})


func _refresh_hud_async() -> void:
	await _refresh_hud()


func _format_num(n: int) -> String:
	if n >= 10000:
		return "%.1f万" % (float(n) / 10000.0)
	return "%d" % n
