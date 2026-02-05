# summon_replace_interaction_context.gd
class_name SummonReplaceInteractionContext
extends EscrowCardInteractionContext
# EscrowCardInteractionContext provides:
#   var card: UsableCard
#   var card_ctx: CardActionContext
#   var effect: Effect

var skip_action: CardAction

var ghost: Node2D
var candidates: Array[SummonedAlly] = []
var resolving := false
var insert_index := 0


func enter() -> void:
	resolving = false

	# Safety: require a SummonEffect
	var summon_effect := effect as SummonEffect
	if summon_effect == null:
		push_warning("SummonReplaceInteractionContext.enter(): effect is not SummonEffect")
		# Bail safely
		handler.end_active_context()
		return

	insert_index = summon_effect.insert_index

	handler.lock_for_modal()

	# Candidates: summoned allies only
	candidates.clear()
	for f in handler.battle_scene.get_combatants_in_group(0):
		if f is SummonedAlly and f.is_alive():
			candidates.append(f)

	# Single-button prompt: Cancel
	handler.prompt_show("Choose a summon to replace.", "Cancel")

	# Preview ghost + preview slot
	ghost = handler.make_summon_ghost(summon_effect)
	(handler.battle_scene.groups[0] as BattleGroupFriendly).set_preview(ghost, insert_index)

	for a in candidates:
		handler.set_candidate_selectable_visuals(a, true)


func exit() -> void:
	# Clean preview + visuals
	var friendly := handler.battle_scene.groups[0] as BattleGroupFriendly
	friendly.clear_preview()

	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	for a in candidates:
		handler.set_candidate_selectable_visuals(a, false)
	candidates.clear()

	resolving = false
	handler.unlock_from_modal()

	# Restore pending glow after messing with fade marks
	friendly._update_pending_turn_glow()


# Called by BattleInteractionHandler when the single prompt button is pressed in this mode.
func on_primary() -> void:
	# If we're already resolving, ignore cancel.
	# (Handler will still end the context if active != null; we prevent that by leaving active intact.)
	if resolving:
		return
	# Do nothing else; handler will call end_active_context() after this.


func can_target(f: Fighter) -> bool:
	return (f is SummonedAlly) and candidates.has(f)


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
	confirm(f as SummonedAlly)


func confirm(chosen: SummonedAlly) -> void:
	if chosen == null or !is_instance_valid(chosen):
		return

	resolving = true

	# Turn off selectable visuals now
	for a in candidates:
		handler.set_candidate_selectable_visuals(a, false)

	# Fade chosen out, then finish
	var tween := handler.create_tween()
	# If you ever rename this sprite, update here.
	tween.tween_property(chosen.combatant.character_sprite, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func(): _finish_confirm(chosen), CONNECT_ONE_SHOT)


func _finish_confirm(chosen: SummonedAlly) -> void:
	if chosen == null or !is_instance_valid(chosen):
		# Something removed it mid-animation; just bail out cleanly.
		handler.end_active_context()
		return
	
	var friendly := handler.battle_scene.groups[0] as BattleGroupFriendly
	
	# Remove chosen via fade-path (not die())
	friendly.combatant_faded(chosen)
	
	# Clear preview ghost so layout count stays correct
	friendly.clear_preview()
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	# Execute summon effect + apply to card context
	var summon_effect := effect as SummonEffect
	if summon_effect != null:
		summon_effect.execute()
		summon_effect.apply_to_card_context(card_ctx)
	else:
		push_warning("SummonReplaceInteractionContext._finish_confirm(): effect lost SummonEffect type")

	# Commit the rest of the card play (your preferred reusable path in UsableCard)
	# Assumes you implemented this helper:
	#   commit_play(ctx: CardActionContext, skip_action: CardAction, already_spent_mana: bool)
	if card != null and is_instance_valid(card):
		card.commit_play(card_ctx, skip_action, true)

	# Exit modal
	handler.end_active_context()
