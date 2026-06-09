# BottomButtonRow - 4-Tab bottom navigation bar per v4 spec
# Tabs: ⚔️战斗 | 📖技能仓库 | 🏪商店 | 🏆排行榜
class_name BottomButtonRow
extends Control

enum Tab { BATTLE, SKILL, SHOP, LEADERBOARD }

signal tab_pressed(tab: int)

@onready var battle_btn: Button = $BattleBtn
@onready var skill_btn: Button = $SkillBtn
@onready var shop_btn: Button = $ShopBtn
@onready var leaderboard_btn: Button = $LeaderboardBtn

var _active_tab: int = Tab.BATTLE

func _ready() -> void:
	battle_btn.pressed.connect(func() -> void: _on_tab(Tab.BATTLE))
	skill_btn.pressed.connect(func() -> void: _on_tab(Tab.SKILL))
	shop_btn.pressed.connect(func() -> void: _on_tab(Tab.SHOP))
	leaderboard_btn.pressed.connect(func() -> void: _on_tab(Tab.LEADERBOARD))
	_update_highlight()
	Log.info("BottomNav", "4-Tab navigation ready")

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
			btn.modulate = Color(0.42, 0.36, 0.91)  # Purple #6c5ce7
		else:
			btn.modulate = Color(0.63, 0.68, 0.75)  # Gray #a0aec0
