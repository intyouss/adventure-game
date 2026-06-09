# SkillInventoryPanel - Skill inventory management and slot assignment
class_name SkillInventoryPanel
extends Control

@onready var grid: GridContainer = $ScrollContainer/Grid
@onready var close_btn: Button = $SkillHeader/CloseBtn
@onready var upgrade_all_btn: Button = $SkillHeader/UpgradeAllBtn
@onready var skill_count_label: Label = $SkillHeader/SkillCountLabel

var _slot_buttons: Array[Button] = []
var _slots_bar: HBoxContainer

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	upgrade_all_btn.pressed.connect(_on_upgrade_all)
	EventBus.skill_updated.connect(_on_skills_changed)
	_create_slots_bar()
	_refresh()
	Log.info("SkillInventoryPanel", "Skill inventory panel ready")

func _create_slots_bar() -> void:
	_slots_bar = HBoxContainer.new()
	_slots_bar.name = "SlotsBar"
	# Add to existing SlotsBar node in scene
	var existing_bar: Node = get_node_or_null("SlotsBar")
	if existing_bar:
		_slots_bar = existing_bar
	else:
		add_child(_slots_bar)
		move_child(_slots_bar, 0)

func _on_skills_changed() -> void:
	_render()

func _refresh() -> void:
	await PlayerState.load_skills()
	_render()

func _render() -> void:
	var inventory_size: int = PlayerState.skill_inventory.size()
	skill_count_label.text = "技能列表 (%d)" % inventory_size
	Log.debug("SkillInventoryPanel", "Rendering skill inventory", {"count": inventory_size})

	# Clear slots bar
	for child: Node in _slots_bar.get_children():
		child.queue_free()

	# Render 4 equipped skill slots
	var equipped: Array = PlayerState.skill_equipped
	for i: int in range(4):
		var btn := Button.new()
		var skill_name: String = "[空]"
		var color: Color = Color(0.4, 0.4, 0.4)
		if i < equipped.size() and equipped[i] != null and equipped[i] != "":
			skill_name = _find_skill_name(str(equipped[i]))
			color = _find_skill_color(str(equipped[i]))
		btn.text = "槽%d\n%s" % [i + 1, skill_name]
		btn.modulate = color
		btn.custom_minimum_size = Vector2(100, 50)
		_slots_bar.add_child(btn)

	# Clear skill grid
	for child: Node in grid.get_children():
		child.queue_free()
	_slot_buttons.clear()

	# Sort skills: quality descending, then level descending
	var sorted: Array = PlayerState.skill_inventory.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var qa: int = a.get("quality", 0)
		var qb: int = b.get("quality", 0)
		if qa != qb:
			return qa > qb
		return a.get("level", 1) > b.get("level", 1)
	)

	# Render owned skills
	for i: int in range(sorted.size()):
		var skill: Dictionary = sorted[i]
		var btn := Button.new()
		var model := SkillModel.new().from_dict(skill)
		btn.text = "%s\nLv.%d" % [model.name, model.level]
		btn.modulate = model.get_quality_color()
		var idx: int = i
		btn.pressed.connect(_on_skill_selected.bind(idx))
		grid.add_child(btn)
		_slot_buttons.append(btn)

func _find_skill_name(skill_id: String) -> String:
	for skill: Dictionary in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return skill.get("name", "?")
	return skill_id

func _find_skill_color(skill_id: String) -> Color:
	for skill: Dictionary in PlayerState.skill_inventory:
		if skill.get("skill_id", skill.get("id", "")) == skill_id:
			return SkillModel.new().from_dict(skill).get_quality_color()
	return Color.WHITE

func _on_skill_selected(index: int) -> void:
	if index < 0 or index >= PlayerState.skill_inventory.size():
		return
	var skill: Dictionary = PlayerState.skill_inventory[index]
	var skill_id: String = skill.get("skill_id", skill.get("id", ""))

	var equipped: Array = PlayerState.skill_equipped
	var target_slot: int = -1
	for i: int in range(4):
		if i >= equipped.size() or equipped[i] == null or equipped[i] == "":
			target_slot = i
			break
	if target_slot < 0:
		target_slot = 0

	Log.info("SkillInventoryPanel", "Equipping skill", {"skill_id": skill_id, "slot": target_slot})
	var res: Dictionary = await NetworkManager.request("POST", "/api/skill/equip", {"skill_id": skill_id, "slot": target_slot})
	if res.code == 0:
		await PlayerState.load_skills()
		_refresh()
		EventBus.skill_updated.emit()
		Log.info("SkillInventoryPanel", "Skill equipped", {"skill_id": skill_id, "slot": target_slot})
	else:
		Log.warn("SkillInventoryPanel", "Skill equip failed", {"skill_id": skill_id, "msg": res.msg})

func _on_upgrade_all() -> void:
	Log.info("SkillInventoryPanel", "Upgrading all skills")
	var res: Dictionary = await NetworkManager.request("POST", "/api/skill/upgrade_all", {})
	if res.code == 0:
		await PlayerState.load_skills()
		_refresh()
		EventBus.skill_updated.emit()
		Log.info("SkillInventoryPanel", "All skills upgraded")
	else:
		Log.warn("SkillInventoryPanel", "Upgrade all failed", {"msg": res.msg})

func _on_close() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("_enter_view"):
		parent._enter_view(0)
	else:
		hide()
	Log.debug("SkillInventoryPanel", "Skill inventory panel closed")
