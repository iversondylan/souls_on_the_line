# summon_replace_interaction_context.gd

class_name SummonReplaceInteractionContext
extends EscrowCardInteractionContext


var action_index: int = -1
var preview: SummonPreview

var ghost: Node2D
var candidates: Array[CombatantView] = []
var resolving := false

func enter() -> void:
	resolving = false
	handler.lock_for_modal()

	candidates.clear()
	var bv := handler.battle.battle_view
	if bv == null or card_ctx == null:
		handler.end_active_context()
		return

	for v in bv.get_combatant_views_for_group(0):
		if v == null or !is_instance_valid(v):
			continue
		if int(v.type) == int(CombatantView.Type.PLAYER):
			continue
		if int(v.mortality) == int(CombatantView.Mortality.SOULBOUND):
			candidates.append(v)

	handler.prompt_show("Choose a summon to replace.", "Cancel")

	if preview != null:
		ghost = handler.make_summon_ghost(preview)
		bv.show_summon_preview_ghost(ghost, int(preview.insert_index), 0)

	for v in candidates:
		_set_candidate_mark(v, true)


func exit() -> void:
	var bv := handler.battle.battle_view
	if bv != null:
		bv.clear_summon_preview_ghost()

	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null

	for v in candidates:
		_set_candidate_mark(v, false)
		if v != null and is_instance_valid(v):
			v.show_targeted_arrow(false)

	candidates.clear()
	resolving = false
	handler.unlock_from_modal()


func on_primary() -> void:
	if resolving:
		return

	if card_ctx != null and card_ctx.runtime != null:
		card_ctx.runtime.cancel_waiting_action(card_ctx, action_index)

	handler.end_active_context()


func on_hover(v: CombatantView) -> void:
	if _can_target(v):
		v.show_targeted_arrow(true)


func on_unhover(v: CombatantView) -> void:
	if _can_target(v):
		v.show_targeted_arrow(false)


func on_click(v: CombatantView) -> void:
	if resolving:
		return
	if !_can_target(v):
		return
	_confirm(v)


func _can_target(v: CombatantView) -> bool:
	return v != null and is_instance_valid(v) and candidates.has(v)


func _set_candidate_mark(v: CombatantView, on: bool) -> void:
	if v == null or !is_instance_valid(v):
		return
	if v.has_method("set_fade_mark"):
		v.set_fade_mark(on)


func _confirm(chosen: CombatantView) -> void:
	if resolving:
		return
	if chosen == null or !is_instance_valid(chosen):
		return

	resolving = true

	for v in candidates:
		_set_candidate_mark(v, false)

	var replaced_index := chosen.get_index()

	var payload := {
		Keys.REPLACED_ID: int(chosen.cid),
		Keys.REPLACED_INSERT_INDEX: replaced_index,
	}

	if card_ctx != null and card_ctx.runtime != null:
		card_ctx.runtime.cover_waiting_action_and_continue(card_ctx, action_index, payload)

	handler.end_active_context()
