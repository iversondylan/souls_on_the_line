# swap_partner_interaction_context.gd

class_name SwapPartnerInteractionContext extends EscrowCardInteractionContext

var candidates: Array[CombatantView] = []
var resolving := false

func get_interaction_kind() -> StringName:
	return &"swap"

func request_open() -> bool:
	if card_ctx == null or card_ctx.target_ids.is_empty():
		return false
	return _evaluate_interaction_gate(
		EncounterGateRequest.Kind.OPEN_CARD_INTERACTION,
		card_ctx.target_ids
	)

func enter() -> void:
	resolving = false
	handler.lock_for_modal()

	var bv := handler.battle.battle_view
	if bv == null or card_ctx == null:
		handler.end_active_context()
		return

	candidates.clear()
	for v in bv.get_combatant_views_for_group(0):
		if v == null or !is_instance_valid(v):
			continue
		if !v.is_alive:
			continue
		candidates.append(v)

	handler.prompt_show("Choose a unit to swap with.", "Cancel")

	for v in candidates:
		_set_candidate_mark(v, true)

func exit() -> void:
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
		card_ctx.runtime.cancel_preflight_interaction(card_ctx, action_index)
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
	v.set_fade_mark(on)

func _confirm(chosen: CombatantView) -> void:
	if resolving:
		return
	if chosen == null or !is_instance_valid(chosen):
		return

	var api: SimBattleAPI = card_ctx.api if card_ctx != null else null
	if api == null:
		handler.end_active_context()
		return

	var actor_id := int(api.get_player_id())
	var target_id := int(chosen.cid)
	if actor_id <= 0 or target_id <= 0:
		handler.end_active_context()
		return
	if !_evaluate_interaction_gate(
		EncounterGateRequest.Kind.CONFIRM_CARD_INTERACTION,
		PackedInt32Array([target_id])
	):
		return

	resolving = true
	for v in candidates:
		_set_candidate_mark(v, false)

	var before_ids_arr: Array[int] = api.get_combatants_in_group(0, true)
	var before := PackedInt32Array()
	before.resize(before_ids_arr.size())
	for i in range(before_ids_arr.size()):
		before[i] = int(before_ids_arr[i])

	var payload := {
		Keys.MOVE_UNIT_ID: card_ctx.target_ids[0],
		Keys.TARGET_ID: target_id,
		Keys.WINDUP_ORDER_IDS: before,
	}

	if card_ctx != null and card_ctx.runtime != null:
		card_ctx.runtime.complete_preflight_interaction_and_continue(card_ctx, action_index, payload)

	handler.end_active_context()
