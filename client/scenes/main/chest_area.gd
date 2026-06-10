# ChestArea - Chest opening with horizontal layout (v4)
class_name ChestArea
extends HBoxContainer

@onready var chest_count_label: Label = $ChestCount
@onready var zone_label: Label = $ZoneLabel
@onready var open_btn: Button = $OpenBtn
@onready var upgrade_btn: Button = $UpgradeBtn
@onready var quantity_selector: OptionButton = $QuantitySelector

var _selected_count: int = 1
var _pending_drop: Dictionary = {}
var _keep_connected: bool = false
var _replace_connected: bool = false

func _ready() -> void:
	theme = ThemeManager.theme
	_style_buttons()
	open_btn.pressed.connect(_open_chest)
	upgrade_btn.pressed.connect(_upgrade_zone)
	quantity_selector.add_item("1个")
	quantity_selector.add_item("5个")
	quantity_selector.add_item("10个")
	quantity_selector.add_item("全部")
	quantity_selector.item_selected.connect(func(idx: int) -> void:
		match idx:
			0: _selected_count = 1
			1: _selected_count = 5
			2: _selected_count = 10
			3: _selected_count = PlayerState.chest_count
		Log.debug("ChestArea", "Quantity selected", {"idx": idx, "count": _selected_count})
	)
	quantity_selector.select(0)
	_refresh()
	Log.info("ChestArea", "Chest area ready")


func _style_buttons() -> void:
	var sb_open := StyleBoxFlat.new()
	sb_open.bg_color = ThemeManager.ACCENT_GOLD
	sb_open.corner_radius_top_left = 10
	sb_open.corner_radius_top_right = 10
	sb_open.corner_radius_bottom_left = 10
	sb_open.corner_radius_bottom_right = 10
	sb_open.content_margin_top = 5
	sb_open.content_margin_bottom = 5
	sb_open.content_margin_left = 12
	sb_open.content_margin_right = 12
	open_btn.add_theme_stylebox_override("normal", sb_open)
	open_btn.add_theme_color_override("font_color", Color.WHITE)
	open_btn.add_theme_font_size_override("font_size", 10)

	var sb_up := StyleBoxFlat.new()
	sb_up.bg_color = Color(0.929, 0.949, 0.969)
	sb_up.border_color = ThemeManager.BORDER_LIGHT
	sb_up.border_width_bottom = 2
	sb_up.border_width_top = 2
	sb_up.border_width_left = 2
	sb_up.border_width_right = 2
	sb_up.corner_radius_top_left = 10
	sb_up.corner_radius_top_right = 10
	sb_up.corner_radius_bottom_left = 10
	sb_up.corner_radius_bottom_right = 10
	sb_up.content_margin_top = 5
	sb_up.content_margin_bottom = 5
	sb_up.content_margin_left = 12
	sb_up.content_margin_right = 12
	upgrade_btn.add_theme_stylebox_override("normal", sb_up)
	upgrade_btn.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
	upgrade_btn.add_theme_font_size_override("font_size", 10)


func _refresh() -> void:
	await PlayerState.load_chest_info()
	chest_count_label.text = "箱子: %d" % PlayerState.chest_count
	zone_label.text = "区域Lv.%d" % PlayerState.zone_level


func _get_compare_popup() -> ColorRect:
	var main_ui: Control = get_tree().root.find_child("Main", true, false)
	if not main_ui:
		return null
	return main_ui.get_node_or_null("ComparePopup")


func _open_chest() -> void:
	var count: int = min(_selected_count, PlayerState.chest_count)
	if count < 1:
		return
	Log.info("ChestArea", "Opening chest", {"count": count})
	var res: Dictionary = await NetworkManager.request("POST", "/api/chest/open", {"count": count})
	if res.code == 0:
		var results: Array = []
		if res.data is Array:
			results = res.data
		else:
			results = res.data.get("results", [])
		Log.info("ChestArea", "Chest opened", {"items": results.size()})
		if results.size() > 0:
			_show_compare_popup(results[0])
		await PlayerState.load_all()
		_refresh()
	else:
		Log.warn("ChestArea", "Chest open failed", {"msg": res.msg})


func _show_compare_popup(item: Dictionary) -> void:
	_pending_drop = item
	var model := EquipmentModel.new().from_dict(item)
	var slot: String = item.get("slot", "weapon")

	var compare: ColorRect = _get_compare_popup()
	if not compare:
		return

	var new_label: Label = compare.get_node_or_null("PopupPanel/VBox/NewItemStats")
	var cur_label: Label = compare.get_node_or_null("PopupPanel/VBox/CurrentItemStats")
	var keep_btn: Button = compare.get_node_or_null("PopupPanel/VBox/BtnRow/KeepBtn")
	var replace_btn: Button = compare.get_node_or_null("PopupPanel/VBox/BtnRow/ReplaceBtn")

	if new_label:
		new_label.text = "✨ 新装备 · %s · %s\nATK:+%d  DEF:+%d  HP:+%d" % [
			EquipmentModel.SLOT_NAMES.get(slot, slot),
			model.get_quality_name(),
			item.get("atk", 0), item.get("def", 0), item.get("hp", 0)
		]
		new_label.add_theme_color_override("font_color", model.get_quality_color())

	var equipped_uid: Variant = PlayerState.equipped.get(slot, "")
	if equipped_uid != "" and equipped_uid != null:
		var eq_item: Dictionary = _find_item(str(equipped_uid))
		if not eq_item.is_empty():
			var eq_model := EquipmentModel.new().from_dict(eq_item)
			if cur_label:
				cur_label.text = "当前: %s · %s\nATK:+%d  DEF:+%d  HP:+%d" % [
					EquipmentModel.SLOT_NAMES.get(slot, slot),
					eq_model.get_quality_name(),
					eq_item.get("atk", 0), eq_item.get("def", 0), eq_item.get("hp", 0)
				]
				cur_label.add_theme_color_override("font_color", eq_model.get_quality_color())
			if keep_btn:
				keep_btn.visible = true
			if replace_btn:
				replace_btn.text = "替换新装备"
		else:
			if cur_label:
				cur_label.text = "当前: [空]"
			if keep_btn:
				keep_btn.visible = false
			if replace_btn:
				replace_btn.text = "装备"
	else:
		if cur_label:
			cur_label.text = "当前: [空]"
		if keep_btn:
			keep_btn.visible = false
		if replace_btn:
			replace_btn.text = "装备"

	# Connect buttons (disconnect old connections first)
	if keep_btn:
		if not _keep_connected:
			keep_btn.pressed.connect(_on_keep)
			_keep_connected = true
	if replace_btn:
		if not _replace_connected:
			replace_btn.pressed.connect(_on_replace)
			_replace_connected = true

	compare.visible = true
	Log.debug("ChestArea", "Compare popup shown", {"slot": slot, "quality": model.quality})


func _on_keep() -> void:
	_keep_connected = false
	var item_id: String = _pending_drop.get("id", "")
	if item_id != "":
		await NetworkManager.request("POST", "/api/equipment/decompose", {"item_uids": [item_id]})
	_close_compare_popup()
	_pending_drop = {}
	EventBus.inventory_changed.emit()
	Log.info("ChestArea", "Kept old equipment, decomposed new drop")


func _on_replace() -> void:
	_replace_connected = false
	var item_uid: String = _pending_drop.get("id", "")
	var slot: String = _pending_drop.get("slot", "weapon")
	var equipped_uid: Variant = PlayerState.equipped.get(slot, "")
	if equipped_uid != "" and equipped_uid != null:
		await NetworkManager.request("POST", "/api/equipment/decompose", {"item_uids": [str(equipped_uid)]})
		Log.info("ChestArea", "Decomposed old equipment", {"slot": slot, "uid": str(equipped_uid)})
	await NetworkManager.request("POST", "/api/equipment/equip", {"item_uid": item_uid, "slot": slot})
	await PlayerState.load_equipment()
	_close_compare_popup()
	_pending_drop = {}
	EventBus.inventory_changed.emit()
	Log.info("ChestArea", "Replaced equipment", {"slot": slot})


func _close_compare_popup() -> void:
	var compare: ColorRect = _get_compare_popup()
	if compare:
		compare.visible = false


func _upgrade_zone() -> void:
	var res: Dictionary = await NetworkManager.request("POST", "/api/chest/upgrade_zone")
	if res.code == 0:
		Log.info("ChestArea", "Zone upgraded")
		await _refresh()
	else:
		Log.warn("ChestArea", "Zone upgrade failed", {"msg": res.msg})


func _find_item(item_id: String) -> Dictionary:
	for item: Dictionary in PlayerState.equipment_inventory:
		if item.get("id", "") == item_id:
			return item
	return {}
