# events.gd (global: Events)

extends Node
# the only ones I'm keeping?
signal player_targeted_arrow_visible(show: bool)
signal combatant_view_clicked(combatant: CombatantView)
signal combatant_view_hovered(combatant: CombatantView)
signal combatant_view_unhovered(combatant: CombatantView)
signal summon_reserve_card_released(summoned_id: int, card_uid: String)


## battle flow events
signal live_battle_api_created(api: LiveBattleAPI)
signal battle_reset() #1-way signal to fighters, immediately followed by arcanum call
signal initiate_first_intents()
signal first_friendly_turn_started() #called after start of battle arcana in battle.gd
signal request_activate_arcana_by_type(type: Arcanum.Type)
signal arcana_activated(type: Arcanum.Type)
signal fighter_entered_turn(fighter: Fighter)
signal request_draw_hand()
signal hand_drawn()
signal end_turn_button_pressed()
signal player_turn_completed()
signal hand_discarded()
signal request_enemy_turn()
signal enemy_turn_started()
signal request_friendly_turn()
signal friendly_turn_started()
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
signal n_combatants_changed()
signal focused_gained(status: Status)
#signal summon_reserve_card_released(summoned_ally: SummonedAlly)
signal player_combatant_data_changed()
signal player_modifier_changed()
signal dead_combatant_data(combatant_data: CombatantData)
signal battle_group_empty(battle_group: BattleGroup)
signal mouse_entered_card(usable_card: UsableCard)
signal mouse_exited_card(usable_card: UsableCard)
signal request_draw_cards(ctx: DrawContext)
signal cards_drawn(ctx: DrawContext)
signal hand_card_added(usable_card: UsableCard)
signal card_selection_toggled(card: UsableCard, is_selected: bool)

## summon replace events
#signal combatant_target_clicked(fighter: Fighter)
#signal combatant_target_hovered(fighter: Fighter)
#signal combatant_target_unhovered(fighter: Fighter)
signal request_summon_replace(card: UsableCard, ctx: CardActionContext, effect: SummonEffect, skip_action: CardAction)
signal request_swap_partner(card: UsableCard, ctx: CardActionContext, actor: Fighter, skip_action: CardAction)
signal request_discard_cards(ctx: DiscardContext)
signal discard_selection_started(ctx: DiscardContext)
signal discard_finished(ctx: DiscardContext)
signal hand_discard_animation_finished()
#signal request_summon_replace
#signal combatant_target_clicked
#signal summon_replace_cancel_requested
signal hand_card_clicked(card: UsableCard)
signal selection_prompt_button_pressed()

## info/menu events
signal intent_tooltip_show_requested(intent_display: IntentDisplay)
signal arcanum_tooltip_show_requested(arcanum_display: ArcanumDisplay)
signal tooltip_hide_requested()
signal status_tooltip_requested(statuses: Array[Status])
signal arcanum_popup_requested(arcanum: Arcanum)

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
signal request_shop_modifiers(shop: Shop)
signal shop_modifier_acquired()
signal shop_arcanum_bought(arcanum: Arcanum, gold_cost: int)
signal shop_card_bought(card_data: CardData, gold_cost: int)
