# ShopPanel - Skill gacha shop with independent level system (v4)
# Pet shop replaces equipment shop (locked as "coming soon")
class_name ShopPanel
extends VBoxContainer

@onready var grid: GridContainer = $ScrollContainer/Grid
@onready var close_btn: Button = $ShopHeader/CloseBtn

var _gacha_in_progress: bool = false
var _gacha_buttons: Array[Button] = []

func _ready() -> void:
	theme = ThemeManager.theme
	close_btn.pressed.connect(_on_close)
	_setup_shops()
	_refresh_gacha()
	Log.info("ShopPanel", "Shop panel ready")


func _setup_shops() -> void:
	var shops: Array[Dictionary] = [
		{"name": "技能商店", "icon": "🔮", "available": true},
		{"name": "宠物商店", "icon": "🐾", "available": false},
		{"name": "待扩展", "icon": "✨", "available": false},
		{"name": "待扩展", "icon": "🎁", "available": false},
	]
	for shop: Dictionary in shops:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)

		# Card wrapper
		var card := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		if shop.available:
			sb.bg_color = ThemeManager.BG_PANEL
			sb.border_color = ThemeManager.ACCENT
		else:
			sb.bg_color = Color(0.929, 0.949, 0.969)
			sb.border_color = ThemeManager.BORDER_LIGHT
		sb.border_width_bottom = 2
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.corner_radius_top_left = 12
		sb.corner_radius_top_right = 12
		sb.corner_radius_bottom_left = 12
		sb.corner_radius_bottom_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		card.add_theme_stylebox_override("panel", sb)

		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		inner.alignment = BoxContainer.ALIGNMENT_CENTER

		var name_label := Label.new()
		name_label.text = "%s %s" % [shop.icon, shop.name]
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 13)
		if not shop.available:
			name_label.add_theme_color_override("font_color", ThemeManager.TEXT_DISABLED)
		inner.add_child(name_label)

		if shop.available:
			var ticket_info := Label.new()
			ticket_info.name = "TicketInfo"
			ticket_info.text = "加载中..."
			ticket_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ticket_info.add_theme_font_size_override("font_size", 10)
			ticket_info.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
			inner.add_child(ticket_info)

			var btn_row := HBoxContainer.new()
			btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_row.add_theme_constant_override("separation", 4)

			var counts: Array[int] = [1, 10, 50, 100]
			var labels: Array[String] = ["×1", "×10", "×50", "×100"]
			for i: int in range(counts.size()):
				var btn := Button.new()
				btn.text = labels[i]
				btn.custom_minimum_size = Vector2(50, 32)
				# Style: small accent buttons
				var btn_sb := StyleBoxFlat.new()
				btn_sb.bg_color = ThemeManager.ACCENT
				btn_sb.corner_radius_top_left = 8
				btn_sb.corner_radius_top_right = 8
				btn_sb.corner_radius_bottom_left = 8
				btn_sb.corner_radius_bottom_right = 8
				btn.add_theme_stylebox_override("normal", btn_sb)
				btn.add_theme_color_override("font_color", Color.WHITE)
				btn.add_theme_font_size_override("font_size", 11)
				var count: int = counts[i]
				btn.pressed.connect(func() -> void: _do_gacha(count))
				_gacha_buttons.append(btn)
				btn_row.add_child(btn)
			inner.add_child(btn_row)
		else:
			var lock_icon := Label.new()
			lock_icon.text = "🔒 敬请期待"
			lock_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lock_icon.add_theme_font_size_override("font_size", 11)
			lock_icon.add_theme_color_override("font_color", ThemeManager.TEXT_DISABLED)
			inner.add_child(lock_icon)

		card.add_child(inner)
		cell.add_child(card)
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
			ticket_info.text = "Lv.%d | 券:%d | 累计:%d | 升级:%d抽" % [
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
	# v4-styled gacha result popup
	var overlay := ColorRect.new()
	overlay.name = "GachaOverlay"
	overlay.color = Color(0, 0, 0, 0.5)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var popup := PanelContainer.new()
	popup.name = "GachaResultPopup"
	popup.set_anchors_preset(Control.PRESET_CENTER)
	popup.offset_left = -160
	popup.offset_top = -200
	popup.offset_right = 160
	popup.offset_bottom = 200
	var popup_sb := StyleBoxFlat.new()
	popup_sb.bg_color = ThemeManager.BG_PANEL
	popup_sb.border_color = ThemeManager.ACCENT
	popup_sb.border_width_bottom = 2
	popup_sb.border_width_top = 2
	popup_sb.border_width_left = 2
	popup_sb.border_width_right = 2
	popup_sb.corner_radius_top_left = 16
	popup_sb.corner_radius_top_right = 16
	popup_sb.corner_radius_bottom_left = 16
	popup_sb.corner_radius_bottom_right = 16
	popup_sb.content_margin_top = 16
	popup_sb.content_margin_bottom = 16
	popup_sb.content_margin_left = 16
	popup_sb.content_margin_right = 16
	popup.add_theme_stylebox_override("panel", popup_sb)
	overlay.add_child(popup)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	popup.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "✨ 抽取结果"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ThemeManager.ACCENT)
	vbox.add_child(title)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Scrollable result list
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(280, 240)
	vbox.add_child(scroll)

	var result_list := VBoxContainer.new()
	result_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result_list.add_theme_constant_override("separation", 4)
	scroll.add_child(result_list)

	# Aggregate duplicate skills
	var pull_counts: Dictionary = {}
	var pull_skills: Dictionary = {}
	for skill: Dictionary in results:
		var sid: String = skill.get("id", skill.get("skill_id", "?"))
		if pull_counts.has(sid):
			pull_counts[sid] += 1
		else:
			pull_counts[sid] = 1
			pull_skills[sid] = skill

	# Render each unique skill as a styled card
	for sid: String in pull_counts:
		var skill: Dictionary = pull_skills[sid]
		var skill_name: String = skill.get("name", skill.get("id", "?"))
		var quality: int = skill.get("quality", 1)
		var level: int = skill.get("level", 1)
		var count: int = pull_counts[sid]
		var qcolor: Color = ThemeManager.QUALITY_COLORS.get(quality, Color.WHITE)
		var qname: String = ThemeManager.QUALITY_NAMES.get(quality, "品质%d" % quality)

		var row_card := PanelContainer.new()
		var row_sb := StyleBoxFlat.new()
		row_sb.bg_color = Color(0.969, 0.980, 0.988)
		row_sb.border_color = qcolor
		row_sb.border_width_bottom = 1
		row_sb.border_width_top = 1
		row_sb.border_width_left = 1
		row_sb.border_width_right = 1
		row_sb.corner_radius_top_left = 8
		row_sb.corner_radius_top_right = 8
		row_sb.corner_radius_bottom_left = 8
		row_sb.corner_radius_bottom_right = 8
		row_sb.content_margin_top = 6
		row_sb.content_margin_bottom = 6
		row_sb.content_margin_left = 10
		row_sb.content_margin_right = 10
		row_card.add_theme_stylebox_override("panel", row_sb)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 6)

		var emoji_lbl := Label.new()
		emoji_lbl.text = skill.get("emoji", skill.get("icon", "✨"))
		emoji_lbl.add_theme_font_size_override("font_size", 20)
		row_hbox.add_child(emoji_lbl)

		var info_vbox := VBoxContainer.new()
		info_vbox.add_theme_constant_override("separation", 1)

		var name_lbl := Label.new()
		name_lbl.text = "%s [%s]" % [skill_name, qname]
		name_lbl.add_theme_color_override("font_color", qcolor)
		name_lbl.add_theme_font_size_override("font_size", 12)
		info_vbox.add_child(name_lbl)

		var detail_lbl := Label.new()
		detail_lbl.text = "Lv.%d ×%d" % [level, count]
		detail_lbl.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
		detail_lbl.add_theme_font_size_override("font_size", 10)
		info_vbox.add_child(detail_lbl)

		row_hbox.add_child(info_vbox)
		row_card.add_child(row_hbox)
		result_list.add_child(row_card)

	# Close button
	var close_popup_btn := Button.new()
	close_popup_btn.text = "确 认"
	close_popup_btn.custom_minimum_size.y = 44
	var close_sb := StyleBoxFlat.new()
	close_sb.bg_color = ThemeManager.ACCENT
	close_sb.corner_radius_top_left = 12
	close_sb.corner_radius_top_right = 12
	close_sb.corner_radius_bottom_left = 12
	close_sb.corner_radius_bottom_right = 12
	close_sb.content_margin_top = 10
	close_sb.content_margin_bottom = 10
	close_popup_btn.add_theme_stylebox_override("normal", close_sb)
	close_popup_btn.add_theme_color_override("font_color", Color.WHITE)
	close_popup_btn.add_theme_font_size_override("font_size", 15)
	close_popup_btn.pressed.connect(func() -> void: overlay.queue_free())
	vbox.add_child(close_popup_btn)


func _on_close() -> void:
	var parent: Node = get_parent()
	if parent and parent.has_method("_enter_view"):
		parent._enter_view(0)
	else:
		hide()
	Log.debug("ShopPanel", "Shop panel closed")
