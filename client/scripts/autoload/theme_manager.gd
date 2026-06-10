# ThemeManager - Centralized v4 theme & color definitions
extends Node

# v4 Design Colors
const BG_MAIN := Color(0.969, 0.980, 0.988)         # #f7fafc
const BG_PANEL := Color(1.0, 1.0, 1.0)               # #ffffff
const ACCENT := Color(0.424, 0.361, 0.906)            # #6c5ce7 purple
const ACCENT_RED := Color(1.0, 0.420, 0.420)          # #ff6b6b
const ACCENT_GOLD := Color(0.965, 0.678, 0.333)       # #f6ad55
const ACCENT_GREEN := Color(0.282, 0.867, 0.494)      # #48bb78
const ACCENT_BLUE := Color(0.259, 0.639, 0.882)       # #4299e1
const TEXT_PRIMARY := Color(0.176, 0.216, 0.282)       # #2d3748
const TEXT_SECONDARY := Color(0.443, 0.502, 0.588)     # #718096
const TEXT_DISABLED := Color(0.753, 0.796, 0.878)      # #cbd5e0
const BORDER := Color(0.753, 0.796, 0.878)             # #cbd5e0
const BORDER_LIGHT := Color(0.886, 0.910, 0.941)       # #e2e8f0

# Login gradient
const LOGIN_GRADIENT_TOP := Color(0.910, 0.961, 0.914)  # #e8f5e9
const LOGIN_GRADIENT_MID := Color(0.784, 0.902, 0.788)  # #c8e6c9
const LOGIN_GRADIENT_BOT := Color(0.647, 0.839, 0.655)  # #a5d6a7

# Battle scene
const BATTLE_BG_TOP := Color(0.922, 0.973, 1.0)        # #ebf8ff
const BATTLE_BG_BOT := Color(0.969, 0.980, 0.988)      # #f7fafc
const BATTLE_BORDER := Color(0.745, 0.892, 0.973)       # #bee3f8
const PLAYER_BG := Color(0.565, 0.804, 0.957)           # #90cdf4
const PLAYER_BORDER := Color(0.659, 0.733, 0.882)       # #4299e1
const MONSTER_BG := Color(0.996, 0.698, 0.698)          # #feb2b2
const MONSTER_BORDER := Color(0.961, 0.400, 0.400)      # #f56565

# Quality colors (7-tier)
const QUALITY_COLORS := {
	1: Color(0.627, 0.627, 0.627),    # #a0aec0 common
	2: Color(0.282, 0.867, 0.494),    # #48bb78 fine
	3: Color(0.259, 0.639, 0.882),    # #4299e1 rare
	4: Color(0.624, 0.478, 0.918),    # #9f7aea epic
	5: Color(0.929, 0.537, 0.212),    # #ed8936 legendary
	6: Color(0.961, 0.396, 0.396),    # #f56565 mythic
	7: Color(0.925, 0.788, 0.294),    # #ecc94b divine
}

const QUALITY_NAMES := {
	1: "普通", 2: "优良", 3: "稀有", 4: "史诗",
	5: "传说", 6: "神话", 7: "神祼",
}

var theme: Theme


func _ready() -> void:
	theme = _build_theme()
	Log.info("ThemeManager", "v4 theme built")


func _build_theme() -> Theme:
	var t := Theme.new()

	# ── Button ───────────────────────────────────
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = BG_PANEL
	btn_normal.border_color = BORDER
	btn_normal.border_width_bottom = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.corner_radius_top_left = 12
	btn_normal.corner_radius_top_right = 12
	btn_normal.corner_radius_bottom_left = 12
	btn_normal.corner_radius_bottom_right = 12
	btn_normal.content_margin_top = 6
	btn_normal.content_margin_bottom = 6
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_right = 12
	t.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.969, 0.980, 0.988)
	btn_hover.border_color = ACCENT
	t.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.886, 0.910, 0.941)
	btn_pressed.border_color = ACCENT
	t.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.933, 0.949, 0.965)
	btn_disabled.border_color = BORDER_LIGHT
	t.set_stylebox("disabled", "Button", btn_disabled)

	t.set_color("font_color", "Button", TEXT_PRIMARY)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	t.set_font_size("font_size", "Button", 14)

	# ── Label ────────────────────────────────────
	t.set_color("font_color", "Label", TEXT_PRIMARY)
	t.set_font_size("font_size", "Label", 14)

	# ── LineEdit ─────────────────────────────────
	var input_normal := StyleBoxFlat.new()
	input_normal.bg_color = BG_PANEL
	input_normal.border_color = Color(0.784, 0.902, 0.788)  # #c8e6c9
	input_normal.border_width_bottom = 2
	input_normal.border_width_top = 2
	input_normal.border_width_left = 2
	input_normal.border_width_right = 2
	input_normal.corner_radius_top_left = 12
	input_normal.corner_radius_top_right = 12
	input_normal.corner_radius_bottom_left = 12
	input_normal.corner_radius_bottom_right = 12
	input_normal.content_margin_top = 10
	input_normal.content_margin_bottom = 10
	input_normal.content_margin_left = 14
	input_normal.content_margin_right = 14
	t.set_stylebox("normal", "LineEdit", input_normal)

	var input_focus := input_normal.duplicate()
	input_focus.border_color = ACCENT
	t.set_stylebox("focus", "LineEdit", input_focus)

	t.set_color("font_color", "LineEdit", TEXT_PRIMARY)
	t.set_color("font_placeholder_color", "LineEdit", TEXT_SECONDARY)
	t.set_font_size("font_size", "LineEdit", 14)

	# ── ProgressBar ──────────────────────────────
	var pb_bg := StyleBoxFlat.new()
	pb_bg.bg_color = Color(0.886, 0.910, 0.941)
	pb_bg.corner_radius_top_left = 4
	pb_bg.corner_radius_top_right = 4
	pb_bg.corner_radius_bottom_left = 4
	pb_bg.corner_radius_bottom_right = 4
	t.set_stylebox("background", "ProgressBar", pb_bg)

	var pb_fill := StyleBoxFlat.new()
	pb_fill.bg_color = ACCENT_GREEN
	pb_fill.corner_radius_top_left = 4
	pb_fill.corner_radius_top_right = 4
	pb_fill.corner_radius_bottom_left = 4
	pb_fill.corner_radius_bottom_right = 4
	t.set_stylebox("fill", "ProgressBar", pb_fill)

	# ── ScrollContainer ──────────────────────────
	t.set_color("bg_color", "ScrollContainer", Color.TRANSPARENT)

	# ── Panel ────────────────────────────────────
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color = BG_PANEL
	panel_bg.corner_radius_top_left = 14
	panel_bg.corner_radius_top_right = 14
	panel_bg.corner_radius_bottom_left = 14
	panel_bg.corner_radius_bottom_right = 14
	t.set_stylebox("panel", "Panel", panel_bg)

	return t


# ── Helper factories ──────────────────────────────

static func make_gradient_btn(text: String, color_a: Color, color_b: Color, radius: int = 14) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size.y = 48
	var sb := StyleBoxFlat.new()
	sb.bg_color = color_a
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	return btn


static func make_primary_btn(text: String) -> Button:
	return make_gradient_btn(text, ACCENT_RED, Color(0.933, 0.353, 0.141))


static func make_accent_btn(text: String) -> Button:
	return make_gradient_btn(text, ACCENT, Color(0.533, 0.427, 0.953))


static func make_gold_btn(text: String) -> Button:
	return make_gradient_btn(text, ACCENT_GOLD, Color(0.929, 0.537, 0.212), 10)


static func make_rounded_panel(corner: int = 14, bg: Color = BG_PANEL, border: Color = BORDER_LIGHT, border_w: int = 2) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_bottom = border_w
	sb.border_width_top = border_w
	sb.border_width_left = border_w
	sb.border_width_right = border_w
	sb.corner_radius_top_left = corner
	sb.corner_radius_top_right = corner
	sb.corner_radius_bottom_left = corner
	sb.corner_radius_bottom_right = corner
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	pc.add_theme_stylebox_override("panel", sb)
	return pc


static func make_avatar_panel(emoji: String, is_player: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	if is_player:
		sb.bg_color = PLAYER_BG
		sb.border_color = PLAYER_BORDER
	else:
		sb.bg_color = MONSTER_BG
		sb.border_color = MONSTER_BORDER
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(52, 68)
	var lbl := Label.new()
	lbl.text = emoji
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	pc.add_child(lbl)
	return pc


static func make_skill_slot(emoji: String, style: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	match style:
		"innate":
			sb.bg_color = Color(0.984, 0.827, 0.553)  # #fbd38d
			sb.border_color = Color(0.929, 0.537, 0.212)  # #ed8936
		"equip":
			sb.bg_color = Color(0.922, 0.973, 1.0)  # #ebf8ff
			sb.border_color = Color(0.565, 0.804, 0.957)  # #90cdf4
		_:
			sb.bg_color = Color(0.929, 0.949, 0.969)  # #edf2f7
			sb.border_color = BORDER
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	if style == "empty":
		sb.border_color = BORDER
		sb.border_width_bottom = 0
		sb.border_width_top = 0
		sb.border_width_left = 0
		sb.border_width_right = 0
		sb.set_border_width_all(2)
		sb.set_border_color(BORDER)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(44, 44)
	var lbl := Label.new()
	lbl.text = emoji
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 18)
	pc.add_child(lbl)
	return pc


static func quality_color(quality: int) -> Color:
	return QUALITY_COLORS.get(quality, Color.WHITE)


static func quality_name(quality: int) -> String:
	return QUALITY_NAMES.get(quality, "???")
