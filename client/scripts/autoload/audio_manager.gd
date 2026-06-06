extends Node

var _enabled: bool = true

func play_sfx(sfx_name: String):
	if not _enabled:
		return
	# Placeholder — will play sounds when assets are added
	print("[Audio] Playing: ", sfx_name)

func toggle():
	_enabled = not _enabled
