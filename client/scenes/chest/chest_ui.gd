extends Control

@onready var chest_count_label = $ChestCount
@onready var zone_label = $ZoneInfo
@onready var open_btn = $OpenBtn
@onready var upgrade_btn = $UpgradeBtn
@onready var result_label = $ResultLabel

func _ready():
	open_btn.pressed.connect(_open_chest)
	upgrade_btn.pressed.connect(_upgrade_zone)
	_refresh()

func _refresh():
	await PlayerState.load_chest_info()
	chest_count_label.text = "箱子: %d" % PlayerState.chest_count
	zone_label.text = "区域等级: %d" % PlayerState.zone_level

func _open_chest():
	if PlayerState.chest_count < 1:
		result_label.text = "没有箱子了!"
		return
	var res = await NetworkManager.request("POST", "/api/chest/open")
	if res.code == 0:
		result_label.text = "获得: %s %s" % [EquipmentModel.new().from_dict(res.data).get_quality_name(), res.data.slot]
		EventBus.item_obtained.emit(res.data)
		await PlayerState.load_all()
		_refresh()
	else:
		result_label.text = res.msg

func _upgrade_zone():
	var res = await NetworkManager.request("POST", "/api/chest/upgrade_zone")
	if res.code == 0:
		result_label.text = "升级成功! 当前等级: %d" % res.data.zone_level
		EventBus.gold_changed.emit(-res.data.cost)
		await _refresh()
	else:
		result_label.text = res.msg
