# SkillInventoryPanel - Skill inventory management and slot assignment (v4)
class_name SkillInventoryPanel
extends VBoxContainer

@onready var grid: GridContainer = $ScrollContainer/Grid
@onready var close_btn: Button = $SkillHeader/CloseBtn
@onready var upgrade_all_btn: Button = $SkillHeader/UpgradeAllBtn
@onready var skill_count_label: Label = $SkillHeader/SkillCountLabel

var _slots_bar: HBoxContainer

func _ready() -> void:
	theme = ThemeManager.theme
	close_btn.pressed.connect(_on_close)
	upgrade_all_btn.pressed.connect(_on_upgrade_all)
	EventBus.skill_updated.connect(_on_skills_changed)
	_create_slots_bar()
	_refresh()
	Log.info("SkillInventoryPanel", "Skill inventory panel ready")


func _create_slots_bar() -> void:
	_slots_bar = get_node_or_null("SlotsBar")
	if not _slots_bar:
		_slots_bar = HBoxContainer.new()
		_slots_bar.name = "SlotsBar"
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

	# Render 4 equipped skill slots (v4 style: rounded cards)
	var equipped: Array = PlayerState.skill_equipped
	for i: int in range(4):
		var slot := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.border_width_bottom = 2
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.content_margin_left = 8
		sb.content_margin_right = 8

		var skill_name: String = "[空]"
		if i < equipped.size() and equipped[i] != null and equipped[i] != "":
			skill_name = _find_skill_name(str(equipped[i]))
			var qcolor: Color = _find_skill_color(str(equipped[i]))
			sb.bg_color = Color(0.922, 0.973, 1.0)
			sb.border_color = qcolor
		else:
			sb.bg_color = Color(0.929, 0.949, 0.969)
			sb.border_color = ThemeManager.BORDER
		slot.add_theme_stylebox_override("panel", sb)
		slot.custom_minimum_size = Vector2(70, 50)

		var lbl := Label.new()
		lbl.text = "槽%d\n%s" % [i + 1, skill_name]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		slot.add_child(lbl)
		_slots_bar.add_child(slot)

	# Clear skill grid
	for child: Node in grid.get_children():
		child.queue_free()

	# Sort skills: quality descending, then level descending
	var sorted: Array = PlayerState.skill_inventory.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var qa: int = a.get("quality", 0)
		var qb: int = b.get("quality", 0)
		if qa != qb:
			return qa > qb
		return a.get("level", 1) > b.get("level", 1)
	)

	# Render owned skills as v4-styled clickable cards
	for i: int in range(sorted.size()):
		var skill: Dictionary = sorted[i]
		var model := SkillModel.new().from_dict(skill)
		var card := Button.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeManager.BG_PANEL
		sb.border_color = model.get_quality_color()
		sb.border_width_bottom = 2
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.corner_radius_top_left = 10
		sb.corner_radius_top_right = 10
		sb.corner_radius_bottom_left = 10
		sb.corner_radius_bottom_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		card.add_theme_stylebox_override("normal", sb)
		var sb_hover := sb.duplicate()
		sb_hover.border_color = ThemeManager.ACCENT
		card.add_theme_stylebox_override("hover", sb_hover)

		card.custom_minimum_size = Vector2(70, 70)
		card.text = "%s\n%s\nLv.%d %s" % [
			skill.get("emoji", skill.get("icon", "✨")),
			model.name,
			model.level,
			model.get_quality_name()
		]
		card.add_theme_font_size_override("font_size", 9)
		card.add_theme_color_override("font_color", ThemeManager.TEXT_PRIMARY)
		var idx: int = i
		card.pressed.connect(_on_skill_selected.bind(idx))
		grid.add_child(card)


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
