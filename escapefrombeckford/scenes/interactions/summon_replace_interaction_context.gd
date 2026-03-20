# summon_replace_interaction_context.gd

class_name SummonReplaceInteractionContext
extends InteractionContext

var card: UsableCard
var req: CardPlayRequest
var preview: SummonPreview

var ghost: Node2D
var candidates: Array[CombatantView] = []
var resolving := false

func enter() -> void:
	resolving = false
	handler.lock_for_modal()

	candidates.clear()
	var bv := handler.battle.battle_view
	if bv == null:
		handler.end_active_context()
		return

	# Candidates: friendly SOULBOUND only
	for v in bv.get_combatant_views_for_group(0):
		if v == null or !is_instance_valid(v):
			continue
		if int(v.type) == int(CombatantView.Type.PLAYER):
			continue
		if int(v.mortality) == int(CombatantView.Mortality.SOULBOUND):
			candidates.append(v)

	handler.prompt_show("Choose a summon to replace.", "Cancel")
	print("summon_replace_interaction_context.gd enter() candidates: ", candidates)
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
	candidates.clear()

	resolving = false
	handler.unlock_from_modal()

func on_primary() -> void:
	# Cancel button
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

# summon_replace_interaction_context.gd
# Change: NO tween fade here anymore. SIM events drive visuals.

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

	# Snapshot BEFORE we remove anything in SIM
	var before_ids_arr: Array[int] = api.get_combatants_in_group(0, true) # allow_dead true ok; your SIM uses alive anyway
	var before := PackedInt32Array()
	before.resize(before_ids_arr.size())
	for i in range(before_ids_arr.size()):
		before[i] = int(before_ids_arr[i])

	# Thread snapshot through the card request into SummonAction.activate_sim
	if req.params == null:
		req.params = {}
	req.params[Keys.WINDUP_ORDER_IDS] = before
	req.params[Keys.REPLACED_ID] = int(chosen.cid)

	# 1) SIM fade (emits FADE_WINDUP/FADE_FOLLOWTHROUGH/FADED)
	api.fade_unit(int(chosen.cid), "summon_replace")

	# 2) SIM summon card (SummonAction will read ctx.params[WINDUP_ORDER_IDS])
	var ok := handler.battle._runtime().apply_player_card(req)
	if !ok:
		handler.end_active_context()
		return

	# 3) UI spend + move card
	if card != null and is_instance_valid(card):
		api.spend_mana_for_card(api.get_player_id(), card.card_data)
		Events.card_played.emit(card)
		card._move_to_destination()

	handler.end_active_context()
