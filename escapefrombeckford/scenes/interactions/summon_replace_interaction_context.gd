class_name SummonReplaceInteractionContext
extends EscrowCardInteractionContext
# class EscrowCardInteractionContext has member variables:
#  var card: UsableCard
#  var card_ctx: CardActionContext
#  var effect: Effect

var skip_action: CardAction

var ghost: Node2D
var candidates: Array[SummonedAlly] = []
var resolving := false
var insert_index := 0

func enter() -> void:
	handler.mode = handler.Mode.SUMMON_REPLACE
	handler.lock_for_modal()

	insert_index = effect.insert_index

	# candidates
	candidates.clear()
	for f in handler.battle_scene.get_combatants_in_group(0):
		if f is SummonedAlly and f.is_alive():
			candidates.append(f)

	# show prompt
	handler.prompt_show_cancel_only("Choose a summon to replace.")

	# preview ghost + preview slot
	ghost = handler.make_summon_ghost(effect)
	(handler.battle_scene.groups[0] as BattleGroupFriendly).set_preview(ghost, insert_index)

	for a in candidates:
		handler.set_candidate_selectable_visuals(a, true)


func exit() -> void:
	# clean preview + visuals
	var friendly := handler.battle_scene.groups[0] as BattleGroupFriendly
	friendly.clear_preview()

	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	for a in candidates:
		handler.set_candidate_selectable_visuals(a, false)
	candidates.clear()

	resolving = false
	handler.unlock_from_modal()
	handler.mode = handler.Mode.NORMAL

	# restore glow
	(handler.battle_scene.groups[0] as BattleGroupFriendly)._update_pending_turn_glow()


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
	resolving = true
	for a in candidates:
		handler.set_candidate_selectable_visuals(a, false)

	# fade chosen out, then finish
	var tween := handler.create_tween()
	tween.tween_property(chosen.combatant.character_sprite, "modulate:a", 0.0, 0.18)
	tween.finished.connect(func(): _finish_confirm(chosen), CONNECT_ONE_SHOT)

func _finish_confirm(chosen: SummonedAlly) -> void:
	var friendly := handler.battle_scene.groups[0] as BattleGroupFriendly

	# remove chosen via fade-path
	friendly.combatant_faded(chosen)

	# clear preview ghost so layout correct
	friendly.clear_preview()
	if ghost and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	# perform effect + apply to context
	effect.execute()
	effect.apply_to_card_context(card_ctx)

	# commit rest of card via UsableCard
	card.commit_play(card_ctx, skip_action, true)

	# exit
	handler.end_active_context()
