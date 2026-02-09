# swap_partner_interaction_context.gd

class_name SwapPartnerInteractionContext
extends EscrowCardInteractionContext
# provides: card, card_ctx, effect (we won't use effect; we'll build a MoveEffect ourselves)

var actor: Fighter
var skip_action: CardAction

var candidates: Array[Fighter] = []
var resolving := false

func enter() -> void:
	resolving = false

	if actor == null or !is_instance_valid(actor):
		push_warning("SwapPartnerInteractionContext.enter(): missing actor")
		handler.end_active_context()
		return

	handler.lock_for_modal()
	handler.prompt_show("Choose a target to swap with.", "Cancel")

	# Candidates: same group as actor (friendly OR enemy), alive only
	candidates.clear()
	var group := handler.battle_scene.get_group_for_actor(actor)
	if group == null:
		push_warning("SwapPartnerInteractionContext.enter(): actor has no group")
		handler.end_active_context()
		return

	for f in group.get_combatants():
		if f != null and is_instance_valid(f) and f.is_alive():
			candidates.append(f)

	# Visuals (optional): mark all candidates as selectable
	for f in candidates:
		handler.set_swap_candidate_visuals(f, true)


func exit() -> void:
	# Clear visuals
	for f in candidates:
		handler.set_swap_candidate_visuals(f, false)
		f.hide_targeted_arrow()
	candidates.clear()

	resolving = false
	handler.unlock_from_modal()

	# Restore group glow
	var group := handler.battle_scene.get_group_for_actor(actor)
	if group:
		group._update_pending_turn_glow()


func on_cancel() -> void:
	if resolving:
		return
	# handler will end_active_context()


func can_target(f: Fighter) -> bool:
	return f != null and is_instance_valid(f) and candidates.has(f)


func on_hover(f: Fighter) -> void:
	if can_target(f):
		f.show_targeted_arrow()


func on_unhover(f: Fighter) -> void:
	if can_target(f):
		f.hide_targeted_arrow()


func on_click(f: Fighter) -> void:
	if resolving:
		return
	if !can_target(f):
		return
	_confirm(f)


func _confirm(target: Fighter) -> void:
	resolving = true
	for f in candidates:
		handler.set_swap_candidate_visuals(f, false)

	# Null swap is allowed: target == actor
	var move := MoveEffect.new()
	move.battle_scene = handler.battle_scene
	move.move_type = MoveEffect.MoveType.SWAP_WITH_TARGET
	move.actor = actor
	move.target = target
	move.can_restore_turn = true
	# If you want the sound from the action, you can pass it in via handler/context.
	# move.sound = ...

	move.execute()

	# Commit the card play, skipping the swap action (since we already executed it).
	if card != null and is_instance_valid(card):
		card.commit_play(card_ctx, skip_action, true)

	handler.end_active_context()
