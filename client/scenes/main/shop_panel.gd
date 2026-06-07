extends Control

@onready var grid = $Grid
@onready var close_btn = $CloseBtn

var _gacha_in_progress: bool = false
var _gacha_buttons: Array[Button] = []

func _ready():
	close_btn.pressed.connect(_on_close)
	_setup_shops()
	_refresh_gacha()

func _setup_shops():
	var shops = [
		{"name": "技能商店", "icon": "📜", "available": true},
		{"name": "装备商店", "icon": "⚔️", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
		{"name": "待扩展", "icon": "❓", "available": false},
	]
	for shop in shops:
		var cell = VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)

		var name_label = Label.new()
		name_label.text = "%s %s" % [shop.icon, shop.name]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(name_label)

		if shop.available:
			var ticket_info = Label.new()
			ticket_info.name = "TicketInfo"
			ticket_info.text = "加载中..."
			ticket_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(ticket_info)

			var btn_row = HBoxContainer.new()
			btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_row.add_theme_constant_override("separation", 4)

			var counts = [1, 10, 50, 100]
			var labels = ["抽1次", "抽10次", "抽50次", "抽100次"]
			for i in range(counts.size()):
				var btn = Button.new()
				btn.text = labels[i]
				btn.custom_minimum_size = Vector2(60, 36)
				var count = counts[i]
				btn.pressed.connect(func(): _do_gacha(count))
				_gacha_buttons.append(btn)
				btn_row.add_child(btn)
			cell.add_child(btn_row)
		else:
			var placeholder = Label.new()
			placeholder.text = "即将开放"
			placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			placeholder.modulate = Color(0.5, 0.5, 0.5)
			cell.add_child(placeholder)

		grid.add_child(cell)
	grid.columns = 2

func _refresh_gacha():
	await _load_shop_info()
	_update_tickets()

func _load_shop_info():
	var res = await NetworkManager.request("GET", "/api/skill/shop_info")
	if res.code == 0:
		var data = res.data
		PlayerState.shop_level = data.get("shop_level", 1)
		if data.has("total_pulls"):
			PlayerState.character["total_pulls"] = data.total_pulls
		if data.has("pulls_to_next"):
			PlayerState.character["pulls_to_next"] = data.pulls_to_next
		PlayerState.character["active_qualities"] = data.get("active_qualities", [])

func _update_tickets():
	if grid.get_child_count() > 0:
		var first_cell = grid.get_child(0)
		var ticket_info = first_cell.find_child("TicketInfo", true, false)
		if ticket_info:
			ticket_info.text = "商店Lv.%d | 券: %d | 累计: %d | 距升级: %d抽" % [
				PlayerState.shop_level,
				PlayerState.character.get("skill_tickets", 0),
				PlayerState.character.get("total_pulls", 0),
				PlayerState.character.get("pulls_to_next", 0)
			]

func _do_gacha(count: int):
	if _gacha_in_progress:
		return
	_gacha_in_progress = true
	_disable_gacha_buttons(true)

	print("[UI] skill_gacha count=", count)
	var res = await NetworkManager.request("POST", "/api/skill/gacha", {"count": count})
	if res.code == 0:
		var results = res.data.get("results", res.data.get("skills", []))
		_show_gacha_result_popup(results)
		for skill in results:
			EventBus.item_obtained.emit(skill)
		await PlayerState.load_skills()
		_update_tickets()

	_gacha_in_progress = false
	_disable_gacha_buttons(false)

func _disable_gacha_buttons(disabled: bool):
	for btn in _gacha_buttons:
		btn.disabled = disabled

func _show_gacha_result_popup(results: Array):
	var popup = PopupPanel.new()
	popup.name = "GachaResultPopup"
	popup.size = Vector2(400, 300)

	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	var title = Label.new()
	title.text = "抽取结果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var result_list = VBoxContainer.new()
	scroll.add_child(result_list)

	# Tally results: count occurrences per skill in THIS pull
	var pull_counts = {}
	var pull_skills = {}
	for skill in results:
		var sid = skill.get("id", skill.get("skill_id", "?"))
		if pull_counts.has(sid):
			pull_counts[sid] += 1
		else:
			pull_counts[sid] = 1
			pull_skills[sid] = skill

	var quality_names = {1: "普通", 2: "优秀", 3: "稀有", 4: "精良", 5: "传说"}
	for sid in pull_counts:
		var skill = pull_skills[sid]
		var skill_name = skill.get("name", skill.get("id", "?"))
		var quality = skill.get("quality", 1)
		var level = skill.get("level", 1)
		var count = pull_counts[sid]
		var qname = quality_names.get(quality, "品质%d" % quality)

		var row = Label.new()
		row.text = "%s [%s] Lv.%d ×%d" % [skill_name, qname, level, count]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result_list.add_child(row)

	var close_popup_btn = Button.new()
	close_popup_btn.text = "关闭"
	close_popup_btn.custom_minimum_size.y = 40
	close_popup_btn.pressed.connect(func(): popup.queue_free())
	vbox.add_child(close_popup_btn)

	add_child(popup)
	popup.popup_centered()

func _on_close():
	print("[UI] shop_close")
	var parent = get_parent()
	if parent and parent.has_method("_enter_mode"):
		parent._enter_mode(0)
	else:
		hide()
