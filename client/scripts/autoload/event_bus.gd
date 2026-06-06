extends Node

signal login_success
signal battle_started(stage_id: String)
signal battle_finished(summary: Dictionary)
signal show_message(text: String, is_error: bool)
