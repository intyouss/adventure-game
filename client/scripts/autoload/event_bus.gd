extends Node

signal login_success
signal chest_updated
signal battle_started(stage_id: String)
signal auto_login_success
signal battle_finished(result: Dictionary)
signal reward_received(rewards: Dictionary)
signal level_up(new_level: int)
signal item_obtained(item: Dictionary)
signal gold_changed(new_amount: int)
signal skill_tickets_changed(new_amount: int)
signal inventory_changed
signal skill_updated

func _suppress_unused_signal_warnings():
	if false:
		login_success.emit()
		chest_updated.emit()
		battle_started.emit("")
		auto_login_success.emit()
		battle_finished.emit({})
		reward_received.emit({})
		level_up.emit(1)
		item_obtained.emit({})
		gold_changed.emit(0)
		skill_tickets_changed.emit(0)
		inventory_changed.emit()
		skill_updated.emit()
