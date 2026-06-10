# LeaderboardPanel - Side-slide leaderboard panel (v4)
class_name LeaderboardPanel
extends Control

@onready var panel: Panel = $Panel
@onready var list: ItemList = $Panel/LeaderboardList
@onready var chapter_tabs: HBoxContainer = $Panel/ChapterTabs
@onready var load_more_btn: Button = $Panel/LoadMoreBtn
@onready var collapse_btn: Button = $Panel/Header/CollapseBtn
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var _current_chapter: int = 1
var _current_page: int = 1
var _page_size: int = 50
var _has_more: bool = false
var _is_open: bool = false

func _ready() -> void:
	theme = ThemeManager.theme
	_style_panel()
	collapse_btn.pressed.connect(_collapse)
	load_more_btn.pressed.connect(_load_next_page)
	_setup_chapter_tabs()
	_refresh()
	Log.info("LeaderboardPanel", "Leaderboard panel ready")


func _style_panel() -> void:
	# Panel background
	var sb := StyleBoxFlat.new()
	sb.bg_color = ThemeManager.BG_PANEL
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 0
	sb.corner_radius_bottom_left = 14
	sb.corner_radius_bottom_right = 0
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	panel.add_theme_stylebox_override("panel", sb)


func open_panel() -> void:
	visible = true
	_is_open = true
	anim_player.play("slide_in")
	Log.info("LeaderboardPanel", "Panel opened")


func _collapse() -> void:
	_is_open = false
	anim_player.play("slide_out")
	await anim_player.animation_finished
	visible = false
	Log.info("LeaderboardPanel", "Panel collapsed")


func _setup_chapter_tabs() -> void:
	var group := ButtonGroup.new()
	for ch: int in range(1, 11):
		var btn := Button.new()
		btn.text = "%d" % ch
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(28, 24)
		btn.add_theme_font_size_override("font_size", 10)
		var chapter: int = ch
		btn.button_group = group
		btn.pressed.connect(_switch_chapter.bind(chapter))
		chapter_tabs.add_child(btn)
		if ch == 1:
			btn.button_pressed = true


func _switch_chapter(chapter: int) -> void:
	_current_chapter = chapter
	_current_page = 1
	_refresh()
	Log.debug("LeaderboardPanel", "Chapter switched", {"chapter": chapter})


func _load_next_page() -> void:
	_current_page += 1
	Log.debug("LeaderboardPanel", "Loading next page", {"page": _current_page})
	_load_rankings(true)


func _refresh() -> void:
	_current_page = 1
	list.clear()
	_load_my_rank()
	_load_rankings(false)


func _load_my_rank() -> void:
	var res: Dictionary = await NetworkManager.request("GET", "/api/leaderboard/my_rank?chapter=%d" % _current_chapter)
	if res.code == 0:
		var mr: Dictionary = res.data
		var rank: Variant = mr.get("rank", "?")
		var nickname: String = mr.get("nickname", "?")
		var level: int = mr.get("level", 1)
		var cp: float = mr.get("cp", 0)
		var idx: int = list.get_item_count()
		list.add_item("⭐%3s | 🧙 %-12s | Lv.%3d | CP %.0f" % [rank, nickname, level, cp])
		list.set_item_custom_bg_color(idx, Color(0.2, 0.2, 0.4, 0.5))
		Log.debug("LeaderboardPanel", "My rank loaded", {"rank": rank, "cp": cp})
	else:
		Log.warn("LeaderboardPanel", "Failed to load my rank", {"msg": res.get("msg", "")})


func _load_rankings(append: bool) -> void:
	if not append:
		list.clear()
	var res: Dictionary = await NetworkManager.request("GET", "/api/leaderboard?page=%d&size=%d&chapter=%d" % [_current_page, _page_size, _current_chapter])
	if res.code == 0:
		var rankings: Array = []
		if res.data is Array:
			rankings = res.data
		else:
			rankings = res.data.get("rankings", [])
		_has_more = rankings.size() >= _page_size
		for entry: Dictionary in rankings:
			var rank: Variant = entry.get("rank", "?")
			var nickname: String = entry.get("nickname", "?")
			var level: int = entry.get("level", 1)
			var cp: float = entry.get("cp", 0)
			var medal: String = ""
			match rank:
				1: medal = "🥇"
				2: medal = "🥈"
				3: medal = "🥉"
				_: medal = "%4s" % str(rank)
			list.add_item("%s | 🧙 %-12s | Lv.%3d | CP %.0f" % [medal, nickname, level, cp])
		load_more_btn.visible = _has_more
		Log.debug("LeaderboardPanel", "Rankings loaded", {"count": rankings.size(), "has_more": _has_more})
	else:
		Log.warn("LeaderboardPanel", "Failed to load rankings", {"msg": res.get("msg", "")})
