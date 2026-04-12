# discard_interaction_context.gd
class_name DiscardInteractionContext extends InteractionContext


var discard_ctx: DiscardContext

var _selected: Array[UsableCard] = []
var _cards: Array[UsableCard] = []
var _resolving := false

func enter() -> void:
	
	_resolving = false
	_selected.clear()
	
	if discard_ctx == null or handler == null or handler.hand == null:
		push_warning("DiscardInteractionContext.enter(): missing discard_ctx/hand")
		handler.end_active_context()
		return
	
	# Enter modal-selection mode (suppresses Hand hover logic)
	handler.hand.set_modal_selecting(true)
	
	_cards = handler.hand.get_hand_cards()
	
	if discard_ctx.amount <= 0 or _cards.is_empty():
		discard_ctx.actually_discarded = 0
		Events.discard_finished.emit(discard_ctx)
		handler.end_active_context()
		return
	
	# Auto-discard-all if not enough cards to choose
	if _cards.size() <= discard_ctx.amount:
		_auto_discard_all()
		return
	Events.discard_selection_started.emit(discard_ctx)
	# Force all cards into SELECTION mode
	for c in _cards:
		if c != null and is_instance_valid(c):
			c.interaction = self
			c.card_state_machine.request_state(CardState.State.SELECTION)
	
	# Connect BEFORE any chance of emitting results
	if !Events.card_selection_toggled.is_connected(_on_card_selection_toggled):
		Events.card_selection_toggled.connect(_on_card_selection_toggled)
	
	if !Events.hand_card_added.is_connected(_on_hand_card_added):
		Events.hand_card_added.connect(_on_hand_card_added)
	
	_update_prompt()


func exit() -> void:
	# Leave modal-selection mode (re-enables Hand hover logic)
	if handler != null and handler.hand != null:
		handler.hand.set_modal_selecting(false)
	
	if Events.card_selection_toggled.is_connected(_on_card_selection_toggled):
		Events.card_selection_toggled.disconnect(_on_card_selection_toggled)
	
	if Events.hand_card_added.is_connected(_on_hand_card_added):
		Events.hand_card_added.disconnect(_on_hand_card_added)
	
	# Restore cards back to BASE
	for c in _cards:
		if c != null and is_instance_valid(c):
			c.interaction = null
			c.card_state_machine.request_state(CardState.State.BASE)
	
	_cards.clear()
	_selected.clear()
	_resolving = false
	
	# If you didn’t lock_for_modal(), don’t unlock_from_modal()
	# (unlock_from_modal enables cards etc; you can keep this if you *want* it.)
	# handler.unlock_from_modal()

func on_primary() -> void:
	# "OK"
	if _resolving:
		return
	if _selected.size() != discard_ctx.amount:
		return
	_commit_selected()

func _update_prompt() -> void:
	var remaining := discard_ctx.amount - _selected.size()
	remaining = maxi(remaining, 0)
	handler.prompt_show("Choose %s card(s) to discard." % remaining, "OK")
	handler.prompt_set_enabled(remaining == 0)

func needs_more_selections() -> bool:
	var remaining := discard_ctx.amount - _selected.size()
	if maxi(remaining, 0) > 0:
		return true
	return false

func _on_card_selection_toggled(card: UsableCard, is_selected: bool) -> void:
	if _resolving:
		return
	if card == null or !is_instance_valid(card):
		return
	if !_cards.has(card):
		return
	
	if is_selected:
		# block over-selecting
		if _selected.size() >= discard_ctx.amount:
			# If a card tried to enter SELECTED anyway, force it back
			card.card_state_machine.request_state(CardState.State.SELECTION)
			return
		if !_selected.has(card):
			_selected.append(card)
	else:
		_selected.erase(card)
	
	_update_prompt()

#func _commit_selected() -> void:
	#_resolving = true
	#handler.prompt_set_enabled(false)
	#
	## stop enrolling added cards mid-resolution
	#if Events.hand_card_added.is_connected(_on_hand_card_added):
		#Events.hand_card_added.disconnect(_on_hand_card_added)
	#
	## Remove + discard
	#Events.hand_discard_animation_finished.connect(_on_discard_done, CONNECT_ONE_SHOT)
	#var removed := discard_ctx.hand.remove_cards_by_entities(_selected)
	#discard_ctx.actually_discarded = removed.size()
	#
	#discard_ctx.hand.discard_cards(removed)

func _on_discard_done(chosen_uids: Array[String]) -> void:
	# Route back to SIM first (this unblocks the SIM request)
	if discard_ctx != null and discard_ctx.on_done.is_valid():
		discard_ctx.on_done.call(chosen_uids)

	Events.discard_finished.emit(discard_ctx)
	handler.end_active_context()

func _auto_discard_all() -> void:
	_resolving = true
	handler.prompt_show("Discarding %s card(s)." % _cards.size(), "OK")
	handler.prompt_set_enabled(false)

	# Build uids from _cards
	var chosen_uids: Array[String] = []
	for c in _cards:
		if c != null and is_instance_valid(c) and c.card_data != null:
			c.card_data.ensure_uid()
			chosen_uids.append(String(c.card_data.uid))

	await _execute_discard(chosen_uids)

func _on_hand_card_added(card: UsableCard) -> void:
	if _resolving:
		return
	if card == null or !is_instance_valid(card):
		return
	# Only care about the hand we’re selecting from
	if handler == null or card.hand != handler.hand:
		return
	# If we already have it, ignore
	if _cards.has(card):
		return
	
	_cards.append(card)
	_enroll_card(card)
	
	# Optional: if a draw pushes us to <= amount, you could auto-discard-all,
	# but for Decisive Choice you want selection, so just update prompt.
	_update_prompt()


func _enroll_card(card: UsableCard) -> void:
	if card == null or !is_instance_valid(card):
		return
	# Ensure it’s interactable under modal rules
	card.interaction = self
	card.disabled = false
	card.unhighlight()
	card.selected = false
	card.card_state_machine.request_state(CardState.State.SELECTION)

# discard_interaction_context.gd (inside "confirm/finish" path)
func _get_selected_uids() -> Array[String]:
	var out: Array[String] = []
	for c in _selected:
		if c == null or !is_instance_valid(c):
			continue
		if c.card_data == null:
			continue
		c.card_data.ensure_uid()
		out.append(String(c.card_data.uid))
	return out

func _commit_selected() -> void:
	if handler != null and handler.battle != null:
		var gate_request = EncounterGateRequest.new()
		gate_request.kind = EncounterGateRequest.Kind.CONFIRM_DISCARD
		var gate_result = handler.battle.evaluate_encounter_gate(gate_request)
		if gate_result != null and int(gate_result.verdict) != int(GateResult.Verdict.ALLOW):
			return
	_resolving = true
	handler.prompt_set_enabled(false)

	if Events.hand_card_added.is_connected(_on_hand_card_added):
		Events.hand_card_added.disconnect(_on_hand_card_added)

	# Capture choice deterministically BEFORE we remove/free anything
	var chosen_uids := _get_selected_uids()

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
