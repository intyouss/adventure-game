# BottomButtonRow - 4-Tab bottom navigation bar (v4 cartoon-casual style)
# Tabs: ⚔️战斗 | 📖技能仓库 | 🏪商店 | 🏆排行榜
class_name BottomButtonRow
extends HBoxContainer

enum Tab { BATTLE, SKILL, SHOP, LEADERBOARD }

signal tab_pressed(tab: int)

@onready var battle_btn: Button = $BattleBtn
@onready var skill_btn: Button = $SkillBtn
@onready var shop_btn: Button = $ShopBtn
@onready var leaderboard_btn: Button = $LeaderboardBtn

var _active_tab: int = Tab.BATTLE

func _ready() -> void:
	theme = ThemeManager.theme
	_style_nav()
	battle_btn.pressed.connect(func() -> void: _on_tab(Tab.BATTLE))
	skill_btn.pressed.connect(func() -> void: _on_tab(Tab.SKILL))
	shop_btn.pressed.connect(func() -> void: _on_tab(Tab.SHOP))
	leaderboard_btn.pressed.connect(func() -> void: _on_tab(Tab.LEADERBOARD))
	_update_highlight()
	Log.info("BottomNav", "4-Tab navigation ready")


func _style_nav() -> void:
	# Nav bar background
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeManager.BG_PANEL
	sb.border_color = ThemeManager.BORDER_LIGHT
	sb.border_width_top = 2
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	add_theme_stylebox_override("panel", sb)
	# Style each nav button
	for btn: Button in [battle_btn, skill_btn, shop_btn, leaderboard_btn]:
		btn.add_theme_font_size_override("font_size", 10)
		btn.custom_minimum_size.y = 48


func _on_tab(tab: int) -> void:
	_active_tab = tab
	_update_highlight()
	tab_pressed.emit(tab)
	Log.debug("BottomNav", "Tab pressed", {"tab": Tab.keys()[tab] if tab < Tab.size() else "?"})


func set_active_tab(tab: int) -> void:
	_active_tab = tab
	_update_highlight()


func _update_highlight() -> void:
	var tabs: Array[Button] = [battle_btn, skill_btn, shop_btn, leaderboard_btn]
	for i: int in range(tabs.size()):
		var btn: Button = tabs[i]
		if i == _active_tab:
			btn.add_theme_color_override("font_color", ThemeManager.ACCENT)
			# Active: underline style
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.TRANSPARENT
			sb.border_color = ThemeManager.ACCENT
			sb.border_width_bottom = 3
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("pressed", sb)
		else:
			btn.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color.TRANSPARENT
			sb.border_color = Color.TRANSPARENT
			sb.border_width_bottom = 3
			sb.corner_radius_top_left = 6
			sb.corner_radius_top_right = 6
			btn.add_theme_stylebox_override("normal", sb)
			btn.add_theme_stylebox_override("pressed", sb)
