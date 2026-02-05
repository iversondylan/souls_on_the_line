# discard_interaction_context.gd
class_name DiscardInteractionContext
extends InteractionContext

var discard_ctx: DiscardContext

var _selected: Array[UsableCard] = []
var _hand_cards_cache: Array[UsableCard] = []
var _resolving := false

func enter() -> void:
	_resolving = false
	_selected.clear()

	if discard_ctx == null or discard_ctx.hand == null:
		push_warning("DiscardInteractionContext.enter(): missing discard_ctx/hand")
		handler.end_active_context()
		return

	handler.lock_for_modal()

	# Cache current hand cards
	_hand_cards_cache = discard_ctx.hand.get_hand_cards()

	# Edge case: nothing to discard or amount <= 0
	if discard_ctx.amount <= 0 or _hand_cards_cache.is_empty():
		discard_ctx.actually_discarded = 0
		Events.discard_finished.emit(discard_ctx)
		handler.end_active_context()
		return

	# Auto-resolve if not enough cards
	if _hand_cards_cache.size() <= discard_ctx.amount:
		_auto_discard_all()
		return

	# Otherwise begin selection mode
	Events.hand_card_clicked.connect(_on_hand_card_clicked)
	_update_prompt_and_button()

func exit() -> void:
	# Disconnect if connected
	if Events.hand_card_clicked.is_connected(_on_hand_card_clicked):
		Events.hand_card_clicked.disconnect(_on_hand_card_clicked)

	# Clear selection visuals
	for c in _selected:
		if c != null and is_instance_valid(c):
			c.unhighlight()

	_selected.clear()
	_hand_cards_cache.clear()
	_resolving = false

	handler.unlock_from_modal()

func on_primary() -> void:
	# In DISCARD, primary is OK
	if _resolving:
		return
	if _remaining() != 0:
		return
	_commit_selected_discards()

# ---------------- internal helpers ----------------

func _remaining() -> int:
	return maxi(discard_ctx.amount - _selected.size(), 0)

func _update_prompt_and_button() -> void:
	var r := _remaining()
	handler.prompt_show("Choose %s cards to discard." % r, "OK")
	handler.prompt_set_enabled(r == 0)

func _on_hand_card_clicked(card: UsableCard) -> void:
	if _resolving:
		return
	if card == null or !is_instance_valid(card):
		return

	# Only allow selecting cards that were in hand when we entered discard mode.
	# (Prevents weirdness if other effects modify hand mid-modal.)
	if !_hand_cards_cache.has(card):
		return

	# Toggle selection
	if _selected.has(card):
		_selected.erase(card)
		card.unhighlight()
	else:
		# Block extra selection once we've reached required amount
		if _remaining() == 0:
			return
		_selected.append(card)
		card.highlight()

	_update_prompt_and_button()

func _commit_selected_discards() -> void:
	_resolving = true
	handler.prompt_set_enabled(false)

	# Remove chosen from hand, then animate discard as a batch
	var removed := discard_ctx.hand.remove_cards_by_entities(_selected)
	discard_ctx.actually_discarded = removed.size()

	# Animate discard + deck updates are handled by Hand.discard_hand
	discard_ctx.hand.discard_hand(removed)

	# Wait for the discard animation batch to finish
	Events.hand_discarded.connect(_on_hand_discarded, CONNECT_ONE_SHOT)

func _on_hand_discarded() -> void:
	Events.discard_finished.emit(discard_ctx)
	handler.end_active_context()

func _auto_discard_all() -> void:
	_resolving = true
	handler.prompt_show("Discarding %s card(s)." % _hand_cards_cache.size(), "OK")
	handler.prompt_set_enabled(false)

	# Remove all current hand cards and discard them
	var removed := discard_ctx.hand.remove_cards_by_entities(_hand_cards_cache)
	discard_ctx.actually_discarded = removed.size()
	discard_ctx.hand.discard_hand(removed)

	Events.hand_discarded.connect(_on_hand_discarded, CONNECT_ONE_SHOT)
