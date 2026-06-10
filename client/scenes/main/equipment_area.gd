# EquipmentArea - Equipment slot display (5-column grid, view-only per v4)
class_name EquipmentArea
extends VBoxContainer

const SLOTS: Array[String] = ["weapon", "helmet", "armor", "shoes", "ring1", "ring2", "necklace", "bracer", "belt", "gloves"]
const SLOT_NAMES: Dictionary = {
	"weapon": "武器", "helmet": "头盔", "armor": "铠甲", "shoes": "鞋子",
	"ring1": "戒指1", "ring2": "戒指2", "necklace": "项链", "bracer": "护腕",
	"belt": "腰带", "gloves": "手套",
}
const SLOT_ICONS: Dictionary = {
	"weapon": "⚔️", "helmet": "🪖", "armor": "🛡️", "shoes": "👟",
	"ring1": "💍", "ring2": "💍", "necklace": "📿", "bracer": "🦾",
	"belt": "🪢", "gloves": "🧤",
}

@onready var slot_grid: GridContainer = $SlotGrid

func _ready() -> void:
	theme = ThemeManager.theme
	EventBus.inventory_changed.connect(_refresh)
	_build_grid()
	_refresh()
	Log.info("EquipmentArea", "Equipment area ready (5-col grid, view-only)")


func _build_grid() -> void:
	for slot_name: String in SLOTS:
		var cell := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = ThemeManager.BG_PANEL
		sb.border_color = ThemeManager.BORDER_LIGHT
		sb.border_width_bottom = 2
		sb.border_width_top = 2
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.corner_radius_top_left = 8
		sb.corner_radius_top_right = 8
		sb.corner_radius_bottom_left = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		sb.content_margin_left = 1
		sb.content_margin_right = 1
		cell.add_theme_stylebox_override("panel", sb)
		cell.name = slot_name

		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 1)

		var icon_lbl := Label.new()
		icon_lbl.name = "Icon"
		icon_lbl.text = SLOT_ICONS.get(slot_name, "📦")
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.name = "SlotName"
		name_lbl.text = SLOT_NAMES.get(slot_name, slot_name)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 8)
		name_lbl.add_theme_color_override("font_color", ThemeManager.TEXT_SECONDARY)
		vbox.add_child(name_lbl)

		var quality_lbl := Label.new()
		quality_lbl.name = "Quality"
		quality_lbl.text = ""
		quality_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		quality_lbl.add_theme_font_size_override("font_size", 9)
		vbox.add_child(quality_lbl)

		cell.add_child(vbox)
		slot_grid.add_child(cell)


func _refresh() -> void:
	Log.debug("EquipmentArea", "Refreshing equipment display")
	for slot_name: String in SLOTS:
		var cell: PanelContainer = slot_grid.get_node_or_null(slot_name) as PanelContainer
		if not cell:
			continue
		var quality_lbl: Label = _find_child_label(cell, "Quality")
		var name_lbl: Label = _find_child_label(cell, "SlotName")
		var icon_lbl: Label = _find_child_label(cell, "Icon")
		var sb: StyleBoxFlat = cell.get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			sb = sb.duplicate()
		else:
			sb = StyleBoxFlat.new()

		var equip_id: Variant = PlayerState.equipped.get(slot_name, "")
		if equip_id != "" and equip_id != null:
			var found: Dictionary = _find_item_by_id(str(equip_id))
			if not found.is_empty():
				var model := EquipmentModel.new().from_dict(found)
				if quality_lbl:
					quality_lbl.text = model.get_quality_name()
					quality_lbl.add_theme_color_override("font_color", model.get_quality_color())
				if icon_lbl:
					icon_lbl.add_theme_color_override("font_color", model.get_quality_color())
				if sb:
					sb.border_color = model.get_quality_color()
			else:
				if quality_lbl:
					quality_lbl.text = "[空]"
					quality_lbl.add_theme_color_override("font_color", ThemeManager.TEXT_DISABLED)
				if sb:
					sb.border_color = ThemeManager.BORDER_LIGHT
		else:
			if quality_lbl:
				quality_lbl.text = "[空]"
				quality_lbl.add_theme_color_override("font_color", ThemeManager.TEXT_DISABLED)
			if sb:
				sb.border_color = ThemeManager.BORDER_LIGHT

		if sb:
			cell.add_theme_stylebox_override("panel", sb)


func _find_child_label(cell: PanelContainer, label_name: String) -> Label:
	for child: Node in cell.get_children():
		if child is VBoxContainer:
			for sub: Node in child.get_children():
				if sub is Label and sub.name == label_name:
					return sub
	return null


func _find_item_by_id(item_id: String) -> Dictionary:
	for item: Dictionary in PlayerState.equipment_inventory:
		if item.get("id", "") == item_id:
			return item
	return {}
