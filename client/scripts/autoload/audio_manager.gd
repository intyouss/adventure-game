# AudioManager - Audio playback control
extends Node

var _enabled: bool = true

func play_sfx(sfx_name: String) -> void:
	if not _enabled:
		return
	Log.debug("Audio", "Playing SFX", {"sfx": sfx_name})

func toggle() -> void:
	_enabled = not _enabled
	Log.info("Audio", "Audio toggled", {"enabled": _enabled})

func is_enabled() -> bool:
	return _enabled
