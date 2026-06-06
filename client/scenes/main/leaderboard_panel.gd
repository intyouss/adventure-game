extends Control

@onready var panel = $Panel
@onready var list = $Panel/LeaderboardList
@onready var chapter_tabs = $Panel/ChapterTabs
@onready var load_more_btn = $Panel/LoadMoreBtn
@onready var collapse_btn = $Panel/CollapseBtn
@onready var anim_player = $AnimationPlayer

var _current_chapter: int = 1
var _current_page: int = 1
var _page_size: int = 50
var _has_more: bool = false
var _is_open: bool = false

func _ready():
	collapse_btn.pressed.connect(_collapse)
	load_more_btn.pressed.connect(_load_next_page)
	_setup_chapter_tabs()
	_refresh()

func open_panel():
	_is_open = true
	anim_player.play("slide_in")

func _collapse():
	_is_open = false
	anim_player.play("slide_out")

func _setup_chapter_tabs():
	for ch in range(1, 11):
		var btn = Button.new()
		btn.text = "第%d章" % ch
		btn.toggle_mode = true
		var chapter = ch
		btn.pressed.connect(func(): _switch_chapter(chapter))
		chapter_tabs.add_child(btn)
		if ch == 1:
			btn.button_pressed = true

func _switch_chapter(chapter: int):
	_current_chapter = chapter
	_current_page = 1
	_refresh()

func _load_next_page():
	_current_page += 1
	_load_rankings(true)

func _refresh():
	_current_page = 1
	list.clear()
	_load_my_rank()
	_load_rankings(false)

func _load_my_rank():
	var res = await NetworkManager.request("GET", "/api/leaderboard/my_rank?chapter=%d" % _current_chapter)
	if res.code == 0:
		var mr = res.data
		var rank = mr.get("rank", "?")
		var nickname = mr.get("nickname", "?")
		var level = mr.get("level", 1)
		var cp = mr.get("cp", 0)
		var idx = list.get_item_count()
		list.add_item("★ %3s | 🧑 %-12s | Lv.%3d | CP %.0f" % [rank, nickname, level, cp])
		list.set_item_custom_bg_color(idx, Color(0.2, 0.2, 0.4, 0.5))

func _load_rankings(append: bool):
	if not append:
		list.clear()

	var res = await NetworkManager.request("GET", "/api/leaderboard?page=%d&size=%d&chapter=%d" % [_current_page, _page_size, _current_chapter])
	if res.code == 0:
		var rankings = res.data.get("rankings", res.data if res.data is Array else [])
		_has_more = rankings.size() >= _page_size
		for entry in rankings:
			var rank = entry.get("rank", "?")
			var nickname = entry.get("nickname", "?")
			var level = entry.get("level", 1)
			var cp = entry.get("cp", 0)
			list.add_item("%4s | 🧑 %-12s | Lv.%3d | CP %.0f" % [rank, nickname, level, cp])
		load_more_btn.visible = _has_more
