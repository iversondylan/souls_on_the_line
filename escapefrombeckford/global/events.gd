extends Node

# battle flow events
signal pre_game_ended()
signal friendly_turn_started()
signal player_turn_started()
signal player_turn_completed()
signal friendly_turn_ended()
signal enemy_turn_started()
signal enemy_turn_ended()
signal game_over_started()
signal victory_started()

# battle mechanics events
signal card_aim_started(usable_card: UsableCard)
signal card_aim_ended(usable_card: UsableCard)
signal battlefield_aim_started(usable_card: UsableCard)
signal battlefield_aim_ended(usable_card: UsableCard)
signal card_drag_started(usable_card: UsableCard)
signal card_drag_ended(usable_card: UsableCard)
signal card_played(usable_card: UsableCard)

signal icon_tooltip_show_requested(usable_icon: UsableIcon)
signal icon_tooltip_hide_requested()

signal hand_drawn()
signal hand_discarded()

signal player_combatant_data_changed()

signal end_turn_button_pressed()

signal summon_reserve_card_released(summoned_ally: SummonedAlly)

signal need_updated_game_state()

signal dead_combatant_data(combatant_data: CombatantData)
signal battle_group_empty(battle_group: BattleGroup)


signal mouse_entered_card(usable_card: UsableCard)
signal mouse_exited_card(usable_card: UsableCard)

# battle transition events
signal battle_over_screen_requested(text: String, outcome: BattleOverPanel.Outcome)
signal battle_won()
signal battle_rewards_exited()

# navigation events
signal map_exited(room: Room)
signal shop_exited()
signal campfire_exited
signal treasure_room_exited()
