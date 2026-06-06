extends Control

@onready var hud = $HUD
@onready var tab_container = $TabContainer
@onready var level_label = $HUD/LevelLabel
@onready var exp_bar = $HUD/ExpBar
@onready var gold_label = $HUD/GoldLabel
@onready var ticket_label = $HUD/TicketLabel
@onready var cp_label = $HUD/CPLabel
@onready var bottom_nav = $BottomNav

func _ready():
	EventBus.login_success.connect(_refresh_hud)
	EventBus.auto_login_success.connect(_refresh_hud)
	_setup_tabs()
	_setup_bottom_nav()
	_refresh_hud()

func _setup_tabs():
	# Tab 0: Equipment, Tab 1: Skill, Tab 2: Chest, Tab 3: Stage, Tab 4: Leaderboard
	tab_container.set_tab_title(0, "装备")
	tab_container.set_tab_title(1, "技能")
	tab_container.set_tab_title(2, "开箱")
	tab_container.set_tab_title(3, "关卡")
	tab_container.set_tab_title(4, "排行榜")

func _setup_bottom_nav():
	var tabs = ["装备", "技能", "开箱", "关卡", "排行榜"]
	for i in range(tabs.size()):
		var btn = bottom_nav.get_child(i) if i < bottom_nav.get_child_count() else null
		if btn and btn is Button:
			var idx = i
			btn.pressed.connect(func(): tab_container.current_tab = idx)

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
