extends Node

signal battle_started(stage_id: String)
signal battle_finished(result: Dictionary)
signal reward_received(rewards: Dictionary)
signal level_up(new_level: int)
signal item_obtained(item: Dictionary)
signal gold_changed(new_amount: int)
signal skill_tickets_changed(new_amount: int)
signal auto_login_success
signal login_success
