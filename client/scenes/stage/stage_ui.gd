extends Control

@onready var progress_label = $ProgressLabel
@onready var stage_list = $StageList
@onready var challenge_btn = $ChallengeBtn

func _ready():
	challenge_btn.pressed.connect(_challenge)
	_refresh()

func _refresh():
	await PlayerState.load_progress()
	progress_label.text = "当前进度: %d-%d" % [PlayerState.stage_chapter, PlayerState.stage_level]
	stage_list.clear()
	for i in range(1, 11):
		var locked = (PlayerState.stage_chapter == 1 and i > PlayerState.stage_level)
		stage_list.add_item("1-%d %s" % [i, "🔒" if locked else "✅" if i < PlayerState.stage_level else "⚔"])

func _challenge():
	var stage_id = "1-%d" % PlayerState.stage_level
	EventBus.battle_started.emit(stage_id)
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
