extends Control

@onready var hud = $HUD
@onready var tabs = $TabContainer
@onready var level_label = $HUD/LevelLabel
@onready var exp_bar = $HUD/ExpBar
@onready var gold_label = $HUD/GoldLabel
@onready var ticket_label = $HUD/TicketLabel
@onready var cp_label = $HUD/CPLabel

func _ready():
	EventBus.login_success.connect(_refresh_hud)
	EventBus.auto_login_success.connect(_refresh_hud)
	_refresh_hud()

func _refresh_hud():
	await PlayerState.load_all()
	var c = PlayerState.character
	if c.is_empty(): return
	level_label.text = "Lv.%d" % c.get("level", 1)
	exp_bar.max_value = c.get("exp_to_next", 100)
	exp_bar.value = c.get("exp", 0)
	gold_label.text = "💰 %d" % c.get("gold", 0)
	ticket_label.text = "🎫 %d" % c.get("skill_tickets", 0)
	cp_label.text = "CP %.0f" % c.get("cp", 0)
