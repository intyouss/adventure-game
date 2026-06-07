extends Control

@onready var progress_label = $ProgressLabel
@onready var stage_list = $StageList
@onready var challenge_btn = $ChallengeBtn
@onready var chapter_tabs = $ChapterTabs

var _current_chapter: int = 1
var _max_chapter: int = 10
var _stage_configs: Dictionary = {}  # chapter -> Array of {stage_id, level, locked}
var _selected_stage_idx: int = -1

func _ready():
	challenge_btn.pressed.connect(_challenge)
	_setup_chapter_tabs()
	_refresh()

func _setup_chapter_tabs():
	for ch in range(1, _max_chapter + 1):
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
	print("[UI] action=stage_chapter chapter=", chapter)
	_load_stage_list()

func _refresh():
	await PlayerState.load_progress()
	progress_label.text = "当前进度: %d-%d" % [PlayerState.stage_chapter, PlayerState.stage_level]
	_load_stage_list()

func _load_stage_list():
	# Fetch stage configs from server for current chapter
	var res = await NetworkManager.request("GET", "/api/stage/config?chapter=%d" % _current_chapter)
	stage_list.clear()
	_stage_configs[_current_chapter] = []

	if res.code == 0:
		var configs = res.data.get("stages", res.data.get("configs", []))
		for cfg in configs:
			var stage_id = cfg.get("stage_id", "%d-%d" % [_current_chapter, cfg.get("level", 1)])
			var level = cfg.get("level", 1)
			var unlocked = _is_unlocked(_current_chapter, level)
			var cleared = _is_cleared(_current_chapter, level)
			var icon = "🔒" if not unlocked else ("✅" if cleared else "⚔")
			stage_list.add_item("%s %s" % [stage_id, icon])
			_stage_configs[_current_chapter].append({
				"stage_id": stage_id,
				"level": level,
				"unlocked": unlocked,
				"cleared": cleared,
			})
	else:
		# Fallback: generate stages 1-10 for chapter
		for i in range(1, 11):
			var stage_id = "%d-%d" % [_current_chapter, i]
			var unlocked = _is_unlocked(_current_chapter, i)
			var cleared = _is_cleared(_current_chapter, i)
			var icon = "🔒" if not unlocked else ("✅" if cleared else "⚔")
			stage_list.add_item("%s %s" % [stage_id, icon])
			_stage_configs[_current_chapter].append({
				"stage_id": stage_id,
				"level": i,
				"unlocked": unlocked,
				"cleared": cleared,
			})

	stage_list.item_selected.connect(_on_stage_selected)

func _is_unlocked(chapter: int, level: int) -> bool:
	if chapter < PlayerState.stage_chapter:
		return true
	if chapter == PlayerState.stage_chapter:
		return level <= PlayerState.stage_level
	return false

func _is_cleared(chapter: int, level: int) -> bool:
	if chapter < PlayerState.stage_chapter:
		return true
	if chapter == PlayerState.stage_chapter:
		return level < PlayerState.stage_level
	return false

func _on_stage_selected(index: int):
	var configs = _stage_configs.get(_current_chapter, [])
	print("[UI] action=stage_selected index=", index)
	if index >= 0 and index < configs.size():
		_selected_stage_idx = index

func _challenge():
	if _selected_stage_idx < 0:
		# Default to current progress
		var stage_id = "%d-%d" % [PlayerState.stage_chapter, PlayerState.stage_level]
		print("[UI] action=challenge stage=", stage_id)
		EventBus.battle_started.emit(stage_id)
		# Use BattleController directly instead of scene change
		var battle_controller = load("res://scenes/battle/battle_controller.gd").new()
		get_tree().root.add_child(battle_controller)
		battle_controller.start_stage(stage_id)
		return

	var configs = _stage_configs.get(_current_chapter, [])
	if _selected_stage_idx >= configs.size():
		return
	var cfg = configs[_selected_stage_idx]
	if not cfg.get("unlocked", false):
		return

	var stage_id = cfg.get("stage_id", "%d-%d" % [_current_chapter, cfg.get("level", 1)])
	print("[UI] action=challenge stage=", stage_id)
	EventBus.battle_started.emit(stage_id)

	# Instantiate BattleController at runtime (no hardcoded tscn dependency)
	var battle_controller = load("res://scenes/battle/battle_controller.gd").new()
	get_tree().root.add_child(battle_controller)
	battle_controller.start_stage(stage_id)
