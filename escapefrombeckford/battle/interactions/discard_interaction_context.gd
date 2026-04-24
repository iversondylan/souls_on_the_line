# discard_interaction_context.gd
class_name DiscardInteractionContext extends InteractionContext

var discard_ctx: DiscardContext

var _selected: Array[UsableCard] = []
var _cards: Array[UsableCard] = []
var _resolving := false

func get_interaction_kind() -> StringName:
	return &"discard"

func request_open() -> bool:
	if discard_ctx == null:
		return false
	return _evaluate_discard_gate(EncounterGateRequest.Kind.OPEN_CARD_INTERACTION)

func enter() -> void:
	_resolving = false
	_selected.clear()

	if discard_ctx == null or handler == null or handler.hand == null:
		push_warning("DiscardInteractionContext.enter(): missing discard_ctx/hand")
		handler.end_active_context()
		return

	handler.hand.set_modal_selecting(true)
	_cards = handler.hand.get_hand_cards()

	if discard_ctx.amount <= 0 or _cards.is_empty():
		discard_ctx.actually_discarded = 0
		Events.discard_finished.emit(discard_ctx)
		handler.end_active_context()
		return

	if _cards.size() <= discard_ctx.amount:
		_auto_discard_all()
		return

	Events.discard_selection_started.emit(discard_ctx)
	for c in _cards:
		if c != null and is_instance_valid(c):
			c.interaction = self
			c.card_state_machine.request_state(CardState.State.SELECTION)

	if !Events.card_selection_toggled.is_connected(_on_card_selection_toggled):
		Events.card_selection_toggled.connect(_on_card_selection_toggled)
	if !Events.hand_card_added.is_connected(_on_hand_card_added):
		Events.hand_card_added.connect(_on_hand_card_added)

	_update_prompt()

func exit() -> void:
	if handler != null and handler.hand != null:
		handler.hand.set_modal_selecting(false)

	if Events.card_selection_toggled.is_connected(_on_card_selection_toggled):
		Events.card_selection_toggled.disconnect(_on_card_selection_toggled)
	if Events.hand_card_added.is_connected(_on_hand_card_added):
		Events.hand_card_added.disconnect(_on_hand_card_added)

	for c in _cards:
		if c != null and is_instance_valid(c):
			c.interaction = null
			c.card_state_machine.request_state(CardState.State.BASE)

	_cards.clear()
	_selected.clear()
	_resolving = false

func on_primary() -> void:
	if _resolving:
		return
	if _selected.size() != discard_ctx.amount:
		return
	_commit_selected()

func _update_prompt() -> void:
	var remaining := maxi(discard_ctx.amount - _selected.size(), 0)
	handler.prompt_show("Choose %s card(s) to discard." % remaining, "OK")
	handler.prompt_set_enabled(remaining == 0)

func needs_more_selections() -> bool:
	return maxi(discard_ctx.amount - _selected.size(), 0) > 0

func _on_card_selection_toggled(card: UsableCard, is_selected: bool) -> void:
	if _resolving:
		return
	if card == null or !is_instance_valid(card):
		return
	if !_cards.has(card):
		return

	if is_selected:
		if _selected.size() >= discard_ctx.amount:
			card.card_state_machine.request_state(CardState.State.SELECTION)
			return
		if !_selected.has(card):
			_selected.append(card)
	else:
		_selected.erase(card)

	_update_prompt()

func _on_discard_done(chosen_uids: Array[String]) -> void:
	if discard_ctx != null and discard_ctx.on_done.is_valid():
		discard_ctx.on_done.call(chosen_uids)
	Events.discard_finished.emit(discard_ctx)
	handler.end_active_context()

func _auto_discard_all() -> void:
	_resolving = true
	handler.prompt_show("Discarding %s card(s)." % _cards.size(), "OK")
	handler.prompt_set_enabled(false)

	var chosen_uids: Array[String] = []
	for c in _cards:
		if c != null and is_instance_valid(c) and c.card_data != null:
			c.card_data.ensure_uid()
			chosen_uids.append(String(c.card_data.uid))

	await _resolve_discard(chosen_uids)

func _on_hand_card_added(card: UsableCard) -> void:
	if _resolving:
		return
	if card == null or !is_instance_valid(card):
		return
	if handler == null or card.hand != handler.hand:
		return
	if _cards.has(card):
		return

	_cards.append(card)
	_enroll_card(card)
	_update_prompt()

func _enroll_card(card: UsableCard) -> void:
	if card == null or !is_instance_valid(card):
		return
	card.interaction = self
	card.disabled = false
	card.unhighlight()
	card.selected = false
	card.card_state_machine.request_state(CardState.State.SELECTION)

func _get_selected_uids() -> Array[String]:
	var out: Array[String] = []
	for c in _selected:
		if c == null or !is_instance_valid(c) or c.card_data == null:
			continue
		c.card_data.ensure_uid()
		out.append(String(c.card_data.uid))
	return out

func _commit_selected() -> void:
	if !_evaluate_discard_gate(EncounterGateRequest.Kind.CONFIRM_CARD_INTERACTION):
		return

	_resolving = true
	handler.prompt_set_enabled(false)

	if Events.hand_card_added.is_connected(_on_hand_card_added):
		Events.hand_card_added.disconnect(_on_hand_card_added)

	await _resolve_discard(_get_selected_uids())

func _resolve_discard(chosen_uids: Array[String]) -> void:
	await _execute_discard(chosen_uids)

func _execute_discard(chosen_uids: Array[String]) -> void:
	if discard_ctx == null:
		return

	discard_ctx.requested_card_uids = chosen_uids.duplicate()
	discard_ctx.amount = chosen_uids.size()

	if handler == null or handler.battle == null or handler.battle.card_bins == null:
		_on_discard_done(chosen_uids)
		return

	await handler.battle.card_bins.request_discard(discard_ctx)
	_on_discard_done(chosen_uids)

func _evaluate_discard_gate(kind: int) -> bool:
	if handler == null or handler.battle == null:
		return true
	var gate_request := EncounterGateRequest.new()
	gate_request.kind = int(kind)
	gate_request.payload = {
		Keys.INTERACTION_KIND: "discard",
	}
	if discard_ctx != null and !discard_ctx.card_uid.is_empty():
		gate_request.card_uid = StringName(discard_ctx.card_uid)
	var gate_result = handler.battle.evaluate_encounter_gate(gate_request)
	return gate_result == null or int(gate_result.verdict) == int(GateResult.Verdict.ALLOW)
