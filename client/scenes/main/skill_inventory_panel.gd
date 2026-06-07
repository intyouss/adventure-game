extends Control

@onready var grid = $ScrollContainer/Grid
@onready var close_btn = $CloseBtn
@onready var upgrade_all_btn = $UpgradeAllBtn

var _slot_buttons: Array = []
var _slots_bar: HBoxContainer

func _ready():
	close_btn.pressed.connect(_on_close)
	upgrade_all_btn.pressed.connect(_on_upgrade_all)
	EventBus.skill_updated.connect(_on_skills_changed)
	_create_slots_bar()
	_refresh()

func _create_slots_bar():
	_slots_bar = HBoxContainer.new()
	_slots_bar.name = "SlotsBar"
	add_child(_slots_bar)
	move_child(_slots_bar, 0)

func _on_skills_changed():
	_render()

func _refresh():
	await PlayerState.load_skills()
	_render()

func _render():
	print("[UI] action=refresh_skill_inventory count=", PlayerState.skill_inventory.size())

	# Clear slots bar
	for child in _slots_bar.get_children():
		child.queue_free()

	# Render 4 equipped skill slots
	var equipped = PlayerState.skill_equipped
	for i in range(4):
		var btn = Button.new()
		var skill_name = "[空]"
		var color = Color(0.4, 0.4, 0.4)
		if i < equipped.size() and equipped[i] != null and equipped[i] != "":
			skill_name = _find_skill_name(str(equipped[i]))
			color = _find_skill_color(str(equipped[i]))
		btn.text = "槽%d\n%s" % [i + 1, skill_name]
		btn.modulate = color
		btn.custom_minimum_size = Vector2(100, 50)
		_slots_bar.add_child(btn)

	# Clear skill grid
	for child in grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	# Sort skills: quality descending, then level descending
	var sorted = PlayerState.skill_inventory.duplicate()
	sorted.sort_custom(func(a, b):
		var qa = a.get("quality", 0)
		var qb = b.get("quality", 0)
		if qa != qb:
			return qa > qb
		return a.get("level", 1) > b.get("level", 1)
	)

	# Render owned skills
	for i in range(sorted.size()):
		var skill = sorted[i]
		var btn = Button.new()
		var model = SkillModel.new().from_dict(skill)
		btn.text = "%s\nLv.%d" % [model.name, model.level]
		btn.modulate = model.get_quality_color()
		var idx = i
		btn.pressed.connect(_on_skill_selected.bind(idx))
		grid.add_child(btn)
		_slot_buttons.append(btn)

	grid.columns = 6

func _find_skill_name(skill_id: String) -> String:
	for skill in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "?")
	return skill_id

func _find_skill_color(skill_id: String) -> Color:
	for skill in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return SkillModel.new().from_dict(skill).get_quality_color()
	return Color.WHITE

func _on_skill_selected(index: int):
	print("[UI] skill_selected index=", index)
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

func _on_upgrade_all():
	print("[UI] upgrade_all_skills")
	var res = await NetworkManager.request("POST", "/api/skill/upgrade_all", {})
	if res.code == 0:
		await PlayerState.load_skills()
		_refresh()
		EventBus.skill_updated.emit()

func _on_close():
	print("[UI] skill_inventory_close")
	var parent = get_parent()
	if parent and parent.has_method("_enter_mode"):
		parent._enter_mode(0)
	else:
		hide()
