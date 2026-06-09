# EventBus - Centralized signal bus for decoupled communication
class_name EventBus
extends Node

# Auth
signal login_success
signal auto_login_success

# Inventory & Equipment
signal inventory_changed
signal chest_updated

# Battle
signal battle_started(stage_id: String)
signal battle_finished(result: Dictionary)

# Rewards
signal reward_received(rewards: Dictionary)
signal item_obtained(item: Dictionary)
signal gold_changed(new_amount: int)
signal skill_tickets_changed(new_amount: int)

# Character
signal level_up(new_level: int)
signal stats_changed
signal skill_updated
