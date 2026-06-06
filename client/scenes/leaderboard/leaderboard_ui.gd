extends Control

@onready var list = $LeaderboardList
@onready var my_rank_label = $MyRankLabel
@onready var refresh_btn = $RefreshBtn

func _ready():
	refresh_btn.pressed.connect(_refresh)
	_refresh()

func _refresh():
	var res = await NetworkManager.request("GET", "/api/leaderboard?chapter=1&n=100")
	if res.code == 0:
		list.clear()
		for entry in res.data:
			var member = entry.get("Member", "?")
			var score = entry.get("Score", 0)
			list.add_item("%s - %.0f分" % [member, score])

	var my_rank = await NetworkManager.request("GET", "/api/leaderboard/my_rank?chapter=1")
	if my_rank.code == 0:
		my_rank_label.text = "我的排名: %d" % my_rank.data.rank
