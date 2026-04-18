# events.gd (global: Events)

extends Node
# the only ones I'm keeping?
signal player_targeted_arrow_visible(show: bool)
signal combatant_view_clicked(combatant: CombatantView)
signal combatant_view_hovered(combatant: CombatantView)
signal combatant_view_unhovered(combatant: CombatantView)
signal summon_reserve_card_acquired(summoned_id: int, card_uid: String)
signal summon_reserve_card_released(summoned_id: int, card_uid: String, overload_mod: int)
signal modify_battle_card(card_uid: String, modified_fields: Dictionary, reason: String)
signal battle_status_changed(target_id: int)
signal mana_view_update(mana_view_order: ManaViewOrder)


## battle flow events
signal hand_drawn()
signal end_turn_button_pressed()
signal player_end_cleanup_started(ctx: HandCleanupContext)
signal player_end_cleanup_completed(ctx: HandCleanupContext)
signal request_victory()
signal request_defeat()


## battle mechanics events
signal card_aim_started(usable_card: UsableCard)
signal card_aim_ended(usable_card: UsableCard)
signal battlefield_aim_started(usable_card: UsableCard)
signal battlefield_aim_ended(usable_card: UsableCard)
signal card_drag_started(usable_card: UsableCard)
signal card_drag_ended(usable_card: UsableCard)
signal card_played(usable_card: UsableCard)
signal dead_combatant_data(combatant_data: CombatantData)
signal request_draw_cards(ctx: DrawContext)
signal execute_discard_cards(ctx: DiscardContext)
signal hand_card_added(usable_card: UsableCard)
signal card_selection_toggled(card: UsableCard, is_selected: bool)
signal player_battle_health_changed(current_health: int, max_health: int)

## summon replace events
signal request_swap_partner(ctx: CardContext, action_index: int)
signal request_discard_cards(ctx: DiscardContext)
signal discard_selection_started(ctx: DiscardContext)
signal discard_finished(ctx: DiscardContext)
signal request_summon_replace(ctx: CardContext, action_index: int, preview: SummonPreview)
signal selection_prompt_button_pressed()

## info/menu events
signal tooltip_source_entered(source: Object, request: TooltipRequest)
signal tooltip_source_exited(source: Object)
signal arcanum_popup_requested(arcanum: Arcanum)
signal turn_status_view_changed(group_index: int, active_id: int, pending_ids: PackedInt32Array, player_id: int)
signal player_input_view_reached(player_id: int)
signal card_scope_view_started(scope_id: int, actor_id: int)
signal card_scope_view_finished(scope_id: int, actor_id: int)
signal arcanum_view_activated(arcanum_id: StringName, proc: int, source_id: int)
signal arcanum_stacks_changed(arcanum_id: StringName, stacks: int)
signal encounter_observed_event(ev)

## battle transition events
signal battle_over_screen_requested(text: String, outcome: BattleOverPanel.Outcome)
signal battle_won()
signal battle_rewards_exited()

## navigation events
signal map_exited(room: Room)
signal shop_exited()
signal campfire_exited
signal treasure_room_exited(found_arcanum: Arcanum)

## Shop related events
signal shop_arcanum_bought(arcanum: Arcanum, gold_cost: int, offer_index: int)
signal shop_card_bought(card_data: CardData, gold_cost: int, offer_index: int)
