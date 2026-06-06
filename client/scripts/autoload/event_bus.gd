extends Node

signal login_success
signal chest_updated
signal battle_started(result: Dictionary)
signal auto_login_success
signal battle_finished(result: Dictionary)
signal reward_received(rewards: Dictionary)
signal level_up(new_level: int)
signal item_obtained(item: Dictionary)
signal gold_changed(new_amount: int)
signal skill_tickets_changed(new_amount: int)
signal skill_updated
