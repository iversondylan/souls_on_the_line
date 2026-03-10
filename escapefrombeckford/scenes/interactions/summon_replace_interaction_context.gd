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

	if preview != null:
		ghost = handler.make_summon_ghost(preview)
		bv.show_summon_preview_ghost(ghost, int(preview.insert_index), 0)

	for v in candidates:
		_set_candidate_mark(v, true)

func exit() -> void:
	var bv := handler.battle.battle_view
	if bv != null:
		bv.clear_summon_preview_ghost()

	ghost = null

	for v in candidates:
		_set_candidate_mark(v, false)
	candidates.clear()

	resolving = false
	handler.unlock_from_modal()

func on_primary() -> void:
	if resolving:
		return
	# cancel => handler ends context

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
	resolving = true
	for v in candidates:
		_set_candidate_mark(v, false)

	var t := handler.create_tween()
	t.tween_property(chosen.character_art, "modulate:a", 0.0, 0.18)
	t.finished.connect(func(): _finish_confirm(chosen), CONNECT_ONE_SHOT)

func _finish_confirm(chosen: CombatantView) -> void:
	if chosen == null or !is_instance_valid(chosen):
		handler.end_active_context()
		return

	# 1) SIM: fade chosen (no death triggers)
	var api := handler.battle.sim_host.get_main_api()
	if api != null:
		api.fade_unit(int(chosen.cid), "summon_replace")

	# 2) SIM: apply the summon request
	var ok := handler.battle.sim_host.apply_player_card(req)
	if !ok:
		handler.end_active_context()
		return

	# 3) UI: spend mana + move card
	if card != null and is_instance_valid(card):
		card.player_data.spend_mana(card.card_data)
		Events.card_played.emit(card)
		card._move_to_destination()

	handler.end_active_context()
