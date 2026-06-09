# ShopPanel - Skill gacha shop with independent level system
class_name ShopPanel
extends Control

@onready var grid: GridContainer = $Grid
@onready var close_btn: Button = $ShopHeader/CloseBtn

var _gacha_in_progress: bool = false
var _gacha_buttons: Array[Button] = []

func _ready() -> void:
	close_btn.pressed.connect(_on_close)
	_setup_shops()
	_refresh_gacha()
	Log.info("ShopPanel", "Shop panel ready")

func _setup_shops() -> void:
	var shops: Array[Dictionary] = [
		{"name": "技能商店", "icon": "🔮", "available": true},
		{"name": "装备商店", "icon": "⚔️", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
	]
	for shop: Dictionary in shops:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)

		var name_label := Label.new()
		name_label.text = "%s %s" % [shop.icon, shop.name]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)

		if shop.available:
			var ticket_info := Label.new()
			ticket_info.name = "TicketInfo"
			ticket_info.text = "加载中..."
			ticket_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(ticket_info)

			var btn_row := HBoxContainer.new()
			btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_row.add_theme_constant_override("separation", 4)

			var counts: Array[int] = [1, 10, 50, 100]
			var labels: Array[String] = ["抽1次", "抽10次", "抽50次", "抽100次"]
			for i: int in range(counts.size()):
				var btn := Button.new()
				btn.text = labels[i]
				btn.custom_minimum_size = Vector2(60, 36)
				var count: int = counts[i]
				btn.pressed.connect(func() -> void: _do_gacha(count))
				_gacha_buttons.append(btn)
				btn_row.add_child(btn)
			cell.add_child(btn_row)
		else:
			var placeholder := Label.new()
			placeholder.text = "即将开放"
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.modulate = Color(0.5, 0.5, 0.5)
			cell.add_child(placeholder)

		grid.add_child(cell)
	grid.columns = 2

func _refresh_gacha() -> void:
	await _load_shop_info()
	_update_tickets()

func _load_shop_info() -> void:
	var res: Dictionary = await NetworkManager.request("GET", "/api/skill/shop_info")
	if res.code == 0:
		var data: Dictionary = res.data
		PlayerState.shop_level = data.get("shop_level", 1)
		if data.has("total_pulls"):
			PlayerState.character["total_pulls"] = data.total_pulls
		if data.has("pulls_to_next"):
			PlayerState.character["pulls_to_next"] = data.pulls_to_next
		PlayerState.character["active_qualities"] = data.get("active_qualities", [])
		Log.info("ShopPanel", "Shop info loaded", {"level": PlayerState.shop_level})
	else:
		Log.warn("ShopPanel", "Failed to load shop info", {"msg": res.msg})

func _update_tickets() -> void:
	if grid.get_child_count() > 0:
		var first_cell: VBoxContainer = grid.get_child(0)
		var ticket_info: Label = first_cell.find_child("TicketInfo", true, false)
		if ticket_info:
			ticket_info.text = "商店Lv.%d | 券: %d | 累计: %d | 距升级: %d抽" % [
				PlayerState.shop_level,
				PlayerState.character.get("skill_tickets", 0),
				PlayerState.character.get("total_pulls", 0),
				PlayerState.character.get("pulls_to_next", 0)
			]

func _do_gacha(count: int) -> void:
	if _gacha_in_progress:
		return
	_gacha_in_progress = true
	_disable_gacha_buttons(true)

	Log.info("ShopPanel", "Starting gacha", {"count": count})
	var res: Dictionary = await NetworkManager.request("POST", "/api/skill/gacha", {"count": count})
	if res.code == 0:
		var results: Array = res.data.get("results", res.data.get("skills", []))
		_show_gacha_result_popup(results)
		for skill: Dictionary in results:
			EventBus.item_obtained.emit(skill)
		await PlayerState.load_skills()
		_update_tickets()
		Log.info("ShopPanel", "Gacha completed", {"count": count, "results": results.size()})
	else:
		Log.warn("ShopPanel", "Gacha failed", {"msg": res.msg})

	_gacha_in_progress = false
	_disable_gacha_buttons(false)

func _disable_gacha_buttons(disabled: bool) -> void:
	for btn: Button in _gacha_buttons:
		btn.disabled = disabled

func _show_gacha_result_popup(results: Array) -> void:
	var popup := PopupPanel.new()
	popup.name = "GachaResultPopup"
	popup.size = Vector2(400, 300)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var title := Label.new()
	title.text = "抽取结果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var result_list := VBoxContainer.new()
	scroll.add_child(result_list)

	var pull_counts: Dictionary = {}
	var pull_skills: Dictionary = {}
	for skill: Dictionary in results:
		var sid: String = skill.get("id", skill.get("skill_id", "?"))
		if pull_counts.has(sid):
			pull_counts[sid] += 1
		else:
			pull_counts[sid] = 1
			pull_skills[sid] = skill

	var quality_names: Dictionary = {1: "普通", 2: "优良", 3: "稀有", 4: "史诗", 5: "传说"}
	for sid: String in pull_counts:
		var skill: Dictionary = pull_skills[sid]
		var skill_name: String = skill.get("name", skill.get("id", "?"))
		var quality: int = skill.get("quality", 1)
		var level: int = skill.get("level", 1)
		var count: int = pull_counts[sid]
		var qname: String = quality_names.get(quality, "品质%d" % quality)

		var row := Label.new()
		row.text = "%s [%s] Lv.%d ×%d" % [skill_name, qname, level, count]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_list.add_child(row)

	var close_popup_btn := Button.new()
	close_popup_btn.text = "关闭"
	close_popup_btn.custom_minimum_size.y = 40
	close_popup_btn.pressed.connect(func() -> void: popup.queue_free())
	vbox.add_child(close_popup_btn)

	add_child(popup)
	popup.popup_centered()

func _on_close() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("_enter_view"):
		parent._enter_view(0)
	else:
		hide()
	Log.debug("ShopPanel", "Shop panel closed")
