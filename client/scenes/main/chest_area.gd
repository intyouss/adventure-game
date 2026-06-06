extends Control

@onready var chest_count_label = $ChestCount
@onready var zone_label = $ZoneLabel
@onready var open_btn = $OpenBtn
@onready var upgrade_btn = $UpgradeBtn
@onready var quantity_selector = $QuantitySelector
@onready var compare_popup = $ComparePopup
@onready var new_item_stats = $ComparePopup/NewItemStats
@onready var current_item_stats = $ComparePopup/CurrentItemStats
@onready var keep_btn = $ComparePopup/KeepBtn
@onready var replace_btn = $ComparePopup/ReplaceBtn

var _selected_count: int = 1
var _pending_drop: Dictionary = {}

func _ready():
	open_btn.pressed.connect(_open_chest)
	upgrade_btn.pressed.connect(_upgrade_zone)
	quantity_selector.add_item("1个")
	quantity_selector.add_item("5个")
	quantity_selector.add_item("10个")
	quantity_selector.add_item("全部")
	quantity_selector.item_selected.connect(func(idx):
		match idx:
			0: _selected_count = 1
			1: _selected_count = 5
			2: _selected_count = 10
			3: _selected_count = PlayerState.chest_count
	)
	quantity_selector.select(0)
	keep_btn.pressed.connect(_on_keep)
	replace_btn.pressed.connect(_on_replace)
	compare_popup.visible = false
	_refresh()

func _refresh():
	await PlayerState.load_chest_info()
	chest_count_label.text = "箱子: %d" % PlayerState.chest_count
	zone_label.text = "区域Lv.%d" % PlayerState.zone_level

func _open_chest():
	var count = min(_selected_count, PlayerState.chest_count)
	if count < 1:
		return
	var res = await NetworkManager.request("POST", "/api/chest/open", {"count": count})
	if res.code == 0:
		var results = res.data.get("results", [])
		if results.size() > 0:
			_show_compare_popup(results[0])
		await PlayerState.load_all()
		_refresh()

func _show_compare_popup(item: Dictionary):
	_pending_drop = item
	var model = EquipmentModel.new().from_dict(item)
	var slot = item.get("slot", "weapon")
	new_item_stats.text = "🎁 %s · %s\nATK:%d  DEF:%d  HP:%d" % [
		EquipmentModel.SLOT_NAMES.get(slot, slot),
		model.get_quality_name(),
		item.get("atk", 0), item.get("def", 0), item.get("hp", 0)
	]

	var equipped_uid = PlayerState.equipped.get(slot, "")
	if equipped_uid != "" and equipped_uid != null:
		var eq_item = _find_item(equipped_uid)
		if not eq_item.is_empty():
			var eq_model = EquipmentModel.new().from_dict(eq_item)
			current_item_stats.text = "当前: %s · %s\nATK:%d  DEF:%d  HP:%d" % [
				EquipmentModel.SLOT_NAMES.get(slot, slot),
				eq_model.get_quality_name(),
				eq_item.get("atk", 0), eq_item.get("def", 0), eq_item.get("hp", 0)
			]
			keep_btn.visible = true
			replace_btn.text = "替换新装备"
		else:
			current_item_stats.text = "当前: [空]"
			keep_btn.visible = false
			replace_btn.text = "装备"
	else:
		current_item_stats.text = "当前: [空]"
		keep_btn.visible = false
		replace_btn.text = "装备"
	compare_popup.visible = true

func _on_keep():
	var uid = _pending_drop.get("uid", _pending_drop.get("id", ""))
	if uid != "":
		await NetworkManager.request("POST", "/api/equipment/decompose", {"item_uids": [uid]})
	compare_popup.visible = false
	_pending_drop = {}
	EventBus.inventory_changed.emit()

func _on_replace():
	var item_uid = _pending_drop.get("uid", _pending_drop.get("id", ""))
	var slot = _pending_drop.get("slot", "weapon")
	await NetworkManager.request("POST", "/api/equipment/equip", {"item_uid": item_uid, "slot": slot})
	await PlayerState.load_equipment()
	compare_popup.visible = false
	_pending_drop = {}
	EventBus.inventory_changed.emit()

func _upgrade_zone():
	var res = await NetworkManager.request("POST", "/api/chest/upgrade_zone")
	if res.code == 0:
		await _refresh()

func _find_item(uid: String) -> Dictionary:
	for item in PlayerState.equipment_inventory:
		if item.get("uid", item.get("id", "")) == uid:
			return item
	return {}
