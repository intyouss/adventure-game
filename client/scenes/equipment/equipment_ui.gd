extends Control

@onready var slot_grid = $SlotGrid
@onready var inventory_list = $InventoryList
@onready var detail_popup = $DetailPopup
@onready var decompose_btn = $DecomposeBtn
@onready var batch_decompose_btn = $BatchDecomposeBtn

var _selected_equip_index: int = -1
var _multi_select: Array = []  # indices selected for batch decompose

func _ready():
	EventBus.inventory_updated.connect(_refresh)
	decompose_btn.pressed.connect(_on_decompose)
	batch_decompose_btn.pressed.connect(_on_batch_decompose)
	inventory_list.multi_selected.connect(_on_multi_select)
	_refresh()

func _refresh():
	inventory_list.clear()
	for i in range(PlayerState.inventory.size()):
		var item = PlayerState.inventory[i]
		var model = EquipmentModel.new().from_dict(item)
		var qcolor = model.get_quality_color()
		inventory_list.add_item("%s [%s] ATK:%d DEF:%d HP:%d" % [
			model.get_slot_name(),
			model.get_quality_name(),
			item.get("atk", 0), item.get("def", 0), item.get("hp", 0)
		])
		# Mark multi-selected items
		if i in _multi_select:
			inventory_list.set_item_custom_bg_color(i, Color.DIM_GRAY)
	_update_slots()

func _update_slots():
	for slot_name in ["weapon","helmet","armor","shoes","ring1","ring2","necklace","bracer","belt","gloves"]:
		var equip_uid = PlayerState.equipped.get(slot_name, "")
		var btn = slot_grid.get_node_or_null(slot_name)
		if btn and btn is Button:
			if equip_uid != "" and equip_uid != null:
				var found = _find_item_by_uid(equip_uid)
				if not found.is_empty():
					var model = EquipmentModel.new().from_dict(found)
					btn.text = "%s\n%s" % [EquipmentModel.SLOT_NAMES.get(slot_name, slot_name), model.get_quality_name()]
					btn.modulate = model.get_quality_color()
				else:
					btn.text = EquipmentModel.SLOT_NAMES.get(slot_name, slot_name)
					btn.modulate = Color.WHITE
			else:
				btn.text = EquipmentModel.SLOT_NAMES.get(slot_name, slot_name) + "\n[空]"
				btn.modulate = Color.WHITE

func _find_item_by_uid(uid: String) -> Dictionary:
	for item in PlayerState.inventory:
		if item.get("uid", item.get("id", "")) == uid:
			return item
	return {}

func _on_multi_select(index: int, selected: bool):
	if selected:
		if index not in _multi_select:
			_multi_select.append(index)
	else:
		_multi_select.erase(index)
	batch_decompose_btn.visible = _multi_select.size() > 0
	_refresh()

func _on_inventory_selected(index: int):
	if index >= 0 and index < PlayerState.inventory.size():
		_selected_equip_index = index
		var item = PlayerState.inventory[index]
		_show_detail_popup(item)

func _show_detail_popup(item: Dictionary):
	detail_popup.visible = true
	var model = EquipmentModel.new().from_dict(item)
	var slot = item.get("slot", "weapon")

	# Show selected item stats
	var selected_label = detail_popup.get_node_or_null("SelectedStats")
	if selected_label:
		selected_label.text = "选中: %s %s\nATK:%d DEF:%d HP:%d" % [
			model.get_slot_name(), model.get_quality_name(),
			item.get("atk", 0), item.get("def", 0), item.get("hp", 0)
		]

	# Show current equipped item for comparison
	var equipped_uid = PlayerState.equipped.get(slot, "")
	var current_label = detail_popup.get_node_or_null("CurrentStats")
	if current_label:
		if equipped_uid != "" and equipped_uid != null:
			var equipped_item = _find_item_by_uid(equipped_uid)
			if not equipped_item.is_empty():
				var eq_model = EquipmentModel.new().from_dict(equipped_item)
				current_label.text = "当前: %s %s\nATK:%d DEF:%d HP:%d" % [
					eq_model.get_slot_name(), eq_model.get_quality_name(),
					equipped_item.get("atk", 0), equipped_item.get("def", 0), equipped_item.get("hp", 0)
				]
			else:
				current_label.text = "当前: [空]"
		else:
			current_label.text = "当前: [空]"

func _on_equip():
	if _selected_equip_index < 0 or _selected_equip_index >= PlayerState.inventory.size():
		return
	var item = PlayerState.inventory[_selected_equip_index]
	var item_uid = item.get("uid", item.get("id", ""))
	var slot = item.get("slot", "weapon")
	await NetworkManager.request("POST", "/api/equipment/equip", {"item_uid": item_uid, "slot": slot})
	await PlayerState.load_equipment()
	_refresh()

func _on_unequip(slot_name: String):
	var equip_uid = PlayerState.equipped.get(slot_name, "")
	if equip_uid == "" or equip_uid == null:
		return
	await NetworkManager.request("POST", "/api/equipment/unequip", {"slot": slot_name})
	await PlayerState.load_equipment()
	_refresh()

func _on_decompose():
	if _selected_equip_index < 0 or _selected_equip_index >= PlayerState.inventory.size():
		return
	var item = PlayerState.inventory[_selected_equip_index]
	var item_uid = item.get("uid", item.get("id", ""))
	_confirm_decompose([item_uid])

func _on_batch_decompose():
	if _multi_select.is_empty():
		return
	var item_uids: Array = []
	for idx in _multi_select:
		if idx >= 0 and idx < PlayerState.inventory.size():
			var item = PlayerState.inventory[idx]
			var uid = item.get("uid", item.get("id", ""))
			if uid != "":
				item_uids.append(uid)
	if item_uids.is_empty():
		return
	_confirm_decompose(item_uids)

func _confirm_decompose(item_uids: Array):
	var confirm = ConfirmationDialog.new()
	confirm.dialog_text = "确定要分解 %d 件装备吗？" % item_uids.size()
	confirm.confirmed.connect(func():
		var res = await NetworkManager.request("POST", "/api/equipment/decompose", {"item_uids": item_uids})
		if res.code == 0:
			EventBus.gold_changed.emit(res.data.get("gold_gained", 0))
			_multi_select.clear()
		await PlayerState.load_equipment()
		_refresh()
	)
	add_child(confirm)
	confirm.popup_centered()
