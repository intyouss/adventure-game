extends Control

@onready var chest_count_label = $ChestCount
@onready var zone_label = $ZoneInfo
@onready var upgrade_cost_label = $UpgradeCostLabel
@onready var open_btn = $OpenBtn
@onready var upgrade_btn = $UpgradeBtn
@onready var result_label = $ResultLabel
@onready var quantity_selector = $QuantitySelector

var _selected_count: int = 1

func _ready():
	open_btn.pressed.connect(_open_chest)
	upgrade_btn.pressed.connect(_upgrade_zone)
	quantity_selector.item_selected.connect(_on_quantity_changed)
	# Populate quantity options: 1, 5, 10, 全部
	quantity_selector.add_item("1个")
	quantity_selector.add_item("5个")
	quantity_selector.add_item("10个")
	quantity_selector.add_item("全部")
	quantity_selector.select(0)
	_refresh()

func _on_quantity_changed(index: int):
	match index:
		0: _selected_count = 1
		1: _selected_count = 5
		2: _selected_count = 10
		3: _selected_count = PlayerState.chest_count  # 全部

func _refresh():
	await PlayerState.load_chest_info()
	chest_count_label.text = "箱子: %d" % PlayerState.chest_count
	zone_label.text = "区域等级: %d" % PlayerState.zone_level

	# Fetch chest info to get upgrade_cost
	var info = await NetworkManager.request("GET", "/api/chest/info")
	if info.code == 0:
		upgrade_cost_label.text = "升级费用: %d 金币" % info.data.get("upgrade_cost", 0)

func _open_chest():
	var count = min(_selected_count, PlayerState.chest_count)
	if count < 1:
		result_label.text = "没有箱子了!"
		return
	var res = await NetworkManager.request("POST", "/api/chest/open", {"count": count})
	if res.code == 0:
		# Parse results array
		var results = res.data.get("results", [])
		if results.size() > 0:
			var first = results[0]
			var model = EquipmentModel.new().from_dict(first)
			result_label.text = "获得 %d 件: %s %s 等" % [results.size(), model.get_quality_name(), first.get("slot", "?")]
			for item in results:
				EventBus.item_obtained.emit(item)
		var remaining = res.data.get("chests_remaining", 0)
		chest_count_label.text = "箱子: %d" % remaining
		await PlayerState.load_all()
		_refresh()
	else:
		result_label.text = res.msg

func _upgrade_zone():
	var res = await NetworkManager.request("POST", "/api/chest/upgrade_zone")
	if res.code == 0:
		var new_level = res.data.get("new_zone_level", PlayerState.zone_level + 1)
		var gold_remaining = res.data.get("gold_remaining", 0)
		result_label.text = "升级成功! 当前等级: %d" % new_level
		EventBus.gold_changed.emit(gold_remaining)
		await _refresh()
	else:
		result_label.text = res.msg
