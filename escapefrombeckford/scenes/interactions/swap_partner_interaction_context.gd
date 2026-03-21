# swap_partner_interaction_context.gd

class_name SwapPartnerInteractionContext extends EscrowCardInteractionContext

var swap_action: SwapWithTargetAction

var candidates: Array[CombatantView] = []
var resolving := false
var actor_view: CombatantView = null

func enter() -> void:
	resolving = false
	handler.lock_for_modal()

	var bv := handler.battle.battle_view
	if bv == null:
		handler.end_active_context()
		return

	var api := handler.battle.sim_host.get_main_api()
	if api == null:
		handler.end_active_context()
		return

	var player_id := int(api.get_player_id())
	actor_view = bv.get_combatant(player_id)
	if actor_view == null or !is_instance_valid(actor_view):
		handler.end_active_context()
		return

	candidates.clear()

	# Friendly group only, alive only, include self so null-swap/self-swap is allowed.
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
	actor_view = null
	handler.unlock_from_modal()

func on_primary() -> void:
	if resolving:
		return
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

	_finish_confirm(chosen)

func _finish_confirm(chosen: CombatantView) -> void:
	if chosen == null or !is_instance_valid(chosen):
		handler.end_active_context()
		return

	var api := handler.battle.sim_host.get_main_api()
	if api == null:
		handler.end_active_context()
		return

	var actor_id := int(api.get_player_id())
	var target_id := int(chosen.cid)

	if actor_id <= 0 or target_id <= 0:
		handler.end_active_context()
		return

	# Snapshot current order before the swap, in case card logic wants it later.
	var before_ids_arr: Array[int] = api.get_combatants_in_group(0, true)
	var before := PackedInt32Array()
	before.resize(before_ids_arr.size())
	for i in range(before_ids_arr.size()):
		before[i] = int(before_ids_arr[i])

	if req.params == null:
		req.params = {}
	req.params[Keys.WINDUP_ORDER_IDS] = before
	req.params[Keys.TARGET_ID] = target_id

	# 1) Execute the card first. Interaction is outside SIM until now.
	var ok := handler.battle._runtime().apply_player_card(req)
	if !ok:
		handler.end_active_context()
		return

	# 2) Only after successful execution, issue the move into SIM.
	var move := MoveContext.new()
	move.move_type = MoveContext.MoveType.SWAP_WITH_TARGET
	move.actor_id = actor_id
	move.target_id = target_id
	move.can_restore_turn = true
	move.sound = swap_action.sound if swap_action != null else null
	api.resolve_move(move)

	if move.sound != null:
		api.play_sfx(move.sound)

	# 3) UI spend + card leave-hand
	if card != null and is_instance_valid(card):
		api.spend_mana_for_card(actor_id, card.card_data)
		Events.card_played.emit(card)
		card._move_to_destination()

	handler.end_active_context()
