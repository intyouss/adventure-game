extends Control

@onready var grid = $ScrollContainer/Grid
@onready var close_btn = $CloseBtn

var _slot_buttons: Array = []

func _ready():
	close_btn.pressed.connect(_on_close)
	EventBus.skill_updated.connect(_refresh)
	_refresh()

func _refresh():
	for child in grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	for i in range(PlayerState.skill_inventory.size()):
		var skill = PlayerState.skill_inventory[i]
		var btn = Button.new()
		var model = SkillModel.new().from_dict(skill)
		btn.text = "%s\nLv.%d" % [model.name, model.level]
		btn.modulate = model.get_quality_color()
		var idx = i
		btn.pressed.connect(func(): _on_skill_selected(idx))
		grid.add_child(btn)
		_slot_buttons.append(btn)

	grid.columns = 6

func _on_skill_selected(index: int):
	if index < 0 or index >= PlayerState.skill_inventory.size():
		return
	var skill = PlayerState.skill_inventory[index]
	var skill_id = skill.get("skill_id", skill.get("id", ""))

	var equipped = PlayerState.skill_equipped
	var target_slot = -1
	for i in range(4):
		if i >= equipped.size() or equipped[i] == null or equipped[i] == "":
			target_slot = i
			break
	if target_slot < 0:
		target_slot = 0

	var res = await NetworkManager.request("POST", "/api/skill/equip", {"skill_id": skill_id, "slot": target_slot})
	if res.code == 0:
		await PlayerState.load_skills()
		_refresh()
		EventBus.skill_updated.emit()

func _on_close():
	var parent = get_parent()
	if parent and parent.has_method("_enter_mode"):
		parent._enter_mode(0)  # Mode.NORMAL = 0
	else:
		hide()
