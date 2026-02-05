# discard_interaction_context.gd
class_name DiscardInteractionContext
extends InteractionContext

var discard_ctx: DiscardContext

var _selected: Array[UsableCard] = []
var _cards: Array[UsableCard] = []
var _resolving := false

func enter() -> void:
	_resolving = false
	_selected.clear()
	discard_ctx.hand.set_modal_selecting(true)
	if discard_ctx == null or discard_ctx.hand == null:
		push_warning("DiscardInteractionContext.enter(): missing discard_ctx/hand")
		handler.end_active_context()
		return

	#handler.lock_for_modal() <- this kind of lock is for summon replace, not selection

	_cards = discard_ctx.hand.get_hand_cards()

	if discard_ctx.amount <= 0 or _cards.is_empty():
		discard_ctx.actually_discarded = 0
		Events.discard_finished.emit(discard_ctx)
		handler.end_active_context()
		return

	# Auto-discard-all if not enough cards to choose
	if _cards.size() <= discard_ctx.amount:
		_auto_discard_all()
		return

	# Force all cards into SELECTION mode
	for c in _cards:
		if c != null and is_instance_valid(c):
			#c.card_state_machine.request_state(CardState.State.BASE)
			c.card_state_machine.request_state(CardState.State.SELECTION)

	Events.card_selection_toggled.connect(_on_card_selection_toggled)
	_update_prompt()

func exit() -> void:
	discard_ctx.hand.set_modal_selecting(true)
	if Events.card_selection_toggled.is_connected(_on_card_selection_toggled):
		Events.card_selection_toggled.disconnect(_on_card_selection_toggled)

	# Restore cards back to BASE
	for c in _cards:
		if c != null and is_instance_valid(c):
			c.card_state_machine.request_state(CardState.State.BASE)

	_cards.clear()
	_selected.clear()
	_resolving = false

	handler.unlock_from_modal()

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

func _commit_selected() -> void:
	_resolving = true
	handler.prompt_set_enabled(false)

	# Remove + discard
	var removed := discard_ctx.hand.remove_cards_by_entities(_selected)
	discard_ctx.actually_discarded = removed.size()

	discard_ctx.hand.discard_hand(removed)

	Events.hand_discarded.connect(_on_discard_done, CONNECT_ONE_SHOT)

func _on_discard_done() -> void:
	Events.discard_finished.emit(discard_ctx)
	handler.end_active_context()

func _auto_discard_all() -> void:
	_resolving = true
	handler.prompt_show("Discarding %s card(s)." % _cards.size(), "OK")
	handler.prompt_set_enabled(false)

	var removed := discard_ctx.hand.remove_cards_by_entities(_cards)
	discard_ctx.actually_discarded = removed.size()
	discard_ctx.hand.discard_hand(removed)

	Events.hand_discarded.connect(_on_discard_done, CONNECT_ONE_SHOT)
