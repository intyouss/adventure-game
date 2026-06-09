# Log - Structured logging system with context-rich formatting
# Usage: Log.info("Network", "Request completed", {"path": "/api/character", "status": 200})
extends Node

enum Level { DEBUG, INFO, WARN, ERROR }

var _min_level: int = Level.DEBUG

## Color codes for terminal output (visible in Godot output panel)
const _LEVEL_COLORS := {
	Level.DEBUG: "[color=gray]",
	Level.INFO: "[color=white]",
	Level.WARN: "[color=yellow]",
	Level.ERROR: "[color=red]",
}
const _COLOR_END := "[/color]"

## Log a debug-level message (verbose, dev-only)
func debug(module: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.DEBUG, module, message, data)

## Log an info-level message (normal operations)
func info(module: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.INFO, module, message, data)

## Log a warning (recoverable issues)
func warn(module: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.WARN, module, message, data)

## Log an error (failures needing attention)
func error(module: String, message: String, data: Dictionary = {}) -> void:
	_log(Level.ERROR, module, message, data)

## Set the minimum log level (Level.DEBUG, Level.INFO, etc.)
func set_level(level: int) -> void:
	_min_level = level
	info("Log", "Log level set", {"level": Level.keys()[level] if level < Level.size() else "UNKNOWN"})

func _log(level: int, module: String, message: String, data: Dictionary = {}) -> void:
	if level < _min_level:
		return
	var level_name: String = Level.keys()[level] if level < Level.size() else "????"
	var timestamp: String = Time.get_datetime_string_from_system()
	var data_str: String = ""
	if not data.is_empty():
		data_str = " | " + JSON.stringify(data)
	var line: String = "[%s][%s][%s] %s%s" % [timestamp, level_name, module, message, data_str]
	print(line)
