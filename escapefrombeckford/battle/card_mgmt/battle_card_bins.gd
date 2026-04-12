class_name BattleCardBins extends Node

signal draw_prepare_requested(ctx: DrawContext)
signal draw_completed(ctx: DrawContext)
signal discard_prepare_requested(ctx: DiscardContext)
signal discard_completed(ctx: DiscardContext)
signal hand_cleanup_prepare_requested(ctx: HandCleanupContext)
signal hand_cleanup_completed(ctx: HandCleanupContext)

var state: CardBinState = CardBinState.new()

var battle: Battle
var hand: Hand
var rule_host: CardBinRuleHost
var rng: RNG

func _ready() -> void:
	_ensure_event_connections()


func setup(new_battle: Battle, new_hand: Hand) -> void:
	battle = new_battle
	hand = new_hand
	if hand != null:
		hand.bins = self
	_ensure_event_connections()


func configure_seed(battle_seed: int) -> void:
	rng = RNG.new(RNGUtil.seed_from_label(int(battle_seed), "battle_card_bins"))


func reset_bins() -> void:
	state.card_collection.clear()
	state.draw_pile.clear()
	state.hand_pile.clear()
	state.discard_pile.clear()
	state.summon_reserve_pile.clear()
	state.exhausted_pile.clear()
	state.summon_reserve_by_uid.clear()
	state.hand_locked_until_next_player_turn.clear()
	state.first_shuffle = true
	state.first_hand_drawn = false


func seed_card_collection(source_pile: CardPile) -> void:
	state.card_collection = CardPile.new()
	if source_pile == null:
		return
	for card: CardData in source_pile.cards:
		if card == null:
			continue
		var new_card := card.make_runtime_instance()
		if new_card == null:
			continue
		new_card.uid = ""
		new_card.ensure_uid()
		state.card_collection.add_back(new_card)


func make_draw_pile() -> void:
	if state.card_collection == null or state.card_collection.cards.is_empty():
		return
	if state.first_shuffle:
		state.draw_pile = state.card_collection.duplicate(true)
		state.first_shuffle = false
	else:
		_take_discards_into_draw()
	if !_is_no_shuffle_mode():
		_shuffle_draw_pile()


func request_draw(ctx: DrawContext) -> void:
	if ctx == null:
		#print("[TRACE battle_card_bins] request_draw: ctx is null")
		return

	#print("[TRACE battle_card_bins] request_draw: source_id=%d amount=%d reason=%s draw_pile=%d hand=%d discard=%d" % [
		#int(ctx.source_id),
		#int(ctx.amount),
		#String(ctx.reason),
		#int(state.draw_pile.cards.size()) if state.draw_pile != null else -1,
		#int(state.hand_pile.cards.size()) if state.hand_pile != null else -1,
		#int(state.discard_pile.cards.size()) if state.discard_pile != null else -1
	#])
	prepare_draw(ctx)
	ctx.drawn_cards = []
	ctx.drawn_card_uids = []
	ctx.actually_drawn = 0
	ctx.drawn_cards = _draw_cards_into_hand(ctx)
	ctx.drawn_card_uids = _uids_for_cards(ctx.drawn_cards)
	ctx.actually_drawn = ctx.drawn_cards.size()
	if bool(ctx.disable_until_next_player_turn):
		for uid in ctx.drawn_card_uids:
			if String(uid).is_empty():
				continue
			state.hand_locked_until_next_player_turn[String(uid)] = true

	if hand != null and !ctx.drawn_cards.is_empty():
		await hand.present_draw_cards(ctx.drawn_cards)

	#print("[TRACE battle_card_bins] request_draw_complete: reason=%s amount=%d actually_drawn=%d hand=%d" % [
		#String(ctx.reason),
		#int(ctx.amount),
		#int(ctx.actually_drawn),
		#int(state.hand_pile.cards.size()) if state.hand_pile != null else -1
	#])
	after_draw(ctx)


func request_discard(ctx: DiscardContext) -> void:
	if ctx == null or hand == null:
		return

	prepare_discard(ctx)

	var chosen_uids := ctx.requested_card_uids.duplicate()
	if chosen_uids.is_empty() and !ctx.card_uid.is_empty():
		chosen_uids.append(ctx.card_uid)
	if chosen_uids.is_empty() and bool(ctx.discard_all_from_hand):
		for card in hand.get_hand_cards():
			if card == null or !is_instance_valid(card) or card.card_data == null:
				continue
			card.card_data.ensure_uid()
			chosen_uids.append(String(card.card_data.uid))
	if chosen_uids.is_empty() and ctx.amount > 0:
		for card in hand.get_hand_cards():
			if card == null or !is_instance_valid(card) or card.card_data == null:
				continue
			card.card_data.ensure_uid()
			chosen_uids.append(String(card.card_data.uid))
			if chosen_uids.size() >= ctx.amount:
				break

	var move_ctx := CardMoveContext.new()
	move_ctx.source_id = ctx.source_id
	move_ctx.from_bin = CardMoveContext.BinKind.HAND
	move_ctx.to_bin = CardMoveContext.BinKind.DISCARD_PILE
	move_ctx.card_uids = chosen_uids
	move_ctx.reason = ctx.reason
	move_ctx.phase = ctx.phase
	move_ctx.tags = ctx.tags.duplicate()
	move_cards(move_ctx)
	_clear_overload_on_cards(move_ctx.moved_cards)

	var removed := hand.get_hand_cards_by_uids(move_ctx.card_uids)
	ctx.discarded_card_uids = move_ctx.card_uids.duplicate()
	ctx.actually_discarded = move_ctx.actually_moved

	if !removed.is_empty():
		await hand.animate_discard_cards(removed, true)

	after_discard(ctx)


func request_hand_cleanup(ctx: HandCleanupContext) -> void:
	if ctx == null or hand == null:
		return

	prepare_hand_cleanup(ctx)
	Events.player_end_cleanup_started.emit(ctx)
	_reduce_overload_for_cards(state.hand_pile.cards, 1)
	_refresh_hand_cards()

	var keep_set := {}
	for uid in ctx.cards_to_keep:
		keep_set[String(uid)] = true

	var discard_uids: Array[String] = []
	var exhaust_uids: Array[String] = []
	ctx.kept_card_uids.clear()

	for card: CardData in state.hand_pile.cards:
		if card == null:
			continue
		card.ensure_uid()
		var uid := String(card.uid)
		if keep_set.has(uid):
			ctx.kept_card_uids.append(uid)
			continue
		if ctx.should_exhaust_hand:
			exhaust_uids.append(uid)
		elif ctx.should_discard_hand:
			discard_uids.append(uid)

	if !discard_uids.is_empty():
		var discard_move := CardMoveContext.new()
		discard_move.source_id = ctx.source_id
		discard_move.from_bin = CardMoveContext.BinKind.HAND
		discard_move.to_bin = CardMoveContext.BinKind.DISCARD_PILE
		discard_move.card_uids = discard_uids
		discard_move.reason = ctx.reason
		discard_move.phase = ctx.phase
		discard_move.tags = ctx.tags.duplicate()
		move_cards(discard_move)

		var discard_cards := hand.get_hand_cards_by_uids(discard_uids)
		ctx.discarded_card_uids = discard_uids.duplicate()
		if !discard_cards.is_empty():
			await hand.animate_discard_cards(discard_cards, false)

	if !exhaust_uids.is_empty():
		var exhaust_move := CardMoveContext.new()
		exhaust_move.source_id = ctx.source_id
		exhaust_move.from_bin = CardMoveContext.BinKind.HAND
		exhaust_move.to_bin = CardMoveContext.BinKind.EXHAUSTED
		exhaust_move.card_uids = exhaust_uids
		exhaust_move.reason = ctx.reason
		exhaust_move.phase = ctx.phase
		exhaust_move.tags = ctx.tags.duplicate()
		move_cards(exhaust_move)

		var exhausted_cards := hand.remove_cards_by_uids(exhaust_uids)
		ctx.exhausted_card_uids = exhaust_uids.duplicate()
		hand.clear_removed_cards(exhausted_cards)

	ctx.actually_moved_card_uids = []
	ctx.actually_moved_card_uids.append_array(ctx.discarded_card_uids)
	ctx.actually_moved_card_uids.append_array(ctx.exhausted_card_uids)

	after_hand_cleanup(ctx)
	Events.player_end_cleanup_completed.emit(ctx)


func move_cards(ctx: CardMoveContext) -> void:
	if ctx == null:
		return

	var from_pile := _get_bin_pile(ctx.from_bin)
	var to_pile := _get_bin_pile(ctx.to_bin)
	if from_pile == null or to_pile == null:
		return

	ctx.moved_cards.clear()
	for uid in ctx.card_uids:
		var card := _remove_card_by_uid(from_pile, String(uid))
		if card == null:
			continue
		state.hand_locked_until_next_player_turn.erase(String(uid))
		to_pile.add_back(card)
		ctx.moved_cards.append(card)
		if ctx.to_bin == CardMoveContext.BinKind.SUMMON_RESERVE:
			state.summon_reserve_by_uid[String(uid)] = card
		if ctx.from_bin == CardMoveContext.BinKind.SUMMON_RESERVE:
			state.summon_reserve_by_uid.erase(String(uid))

	ctx.card_uids = _uids_for_cards(ctx.moved_cards)
	ctx.actually_moved = ctx.moved_cards.size()


func reserve_card_from_hand(card: CardData) -> void:
	if card == null:
		return
	card.ensure_uid()
	var move_ctx := CardMoveContext.new()
	move_ctx.from_bin = CardMoveContext.BinKind.HAND
	move_ctx.to_bin = CardMoveContext.BinKind.SUMMON_RESERVE
	move_ctx.card_uids = [String(card.uid)]
	move_ctx.reason = "reserve_summon_card"
	move_cards(move_ctx)


func discard_card_from_hand(card: CardData) -> void:
	if card == null:
		return
	card.ensure_uid()
	var move_ctx := CardMoveContext.new()
	move_ctx.from_bin = CardMoveContext.BinKind.HAND
	move_ctx.to_bin = CardMoveContext.BinKind.DISCARD_PILE
	move_ctx.card_uids = [String(card.uid)]
	move_ctx.reason = "discard_card"
	move_cards(move_ctx)


func exhaust_card_from_hand(card: CardData) -> void:
	if card == null:
		return
	card.ensure_uid()
	var move_ctx := CardMoveContext.new()
	move_ctx.from_bin = CardMoveContext.BinKind.HAND
	move_ctx.to_bin = CardMoveContext.BinKind.EXHAUSTED
	move_ctx.card_uids = [String(card.uid)]
	move_ctx.reason = "deplete_card"
	move_cards(move_ctx)


func discard_reserved_summon_card(card_uid: String, overload_mod: int) -> void:
	if card_uid.is_empty():
		return
	var move_ctx := CardMoveContext.new()
	move_ctx.from_bin = CardMoveContext.BinKind.SUMMON_RESERVE
	move_ctx.to_bin = CardMoveContext.BinKind.DISCARD_PILE
	move_ctx.card_uids = [card_uid]
	move_ctx.reason = "summon_reserve_release"
	move_cards(move_ctx)
	_set_summon_release_overload(move_ctx.moved_cards, overload_mod)

func build_bin_snapshot() -> CardBinSnapshot:
	var snapshot := CardBinSnapshot.new()
	snapshot.draw_pile_uids = _uids_for_cards(state.draw_pile.cards)
	snapshot.hand_uids = _uids_for_cards(state.hand_pile.cards)
	snapshot.discard_pile_uids = _uids_for_cards(state.discard_pile.cards)
	snapshot.summon_reserve_uids = _uids_for_cards(state.summon_reserve_pile.cards)
	snapshot.exhausted_uids = _uids_for_cards(state.exhausted_pile.cards)
	snapshot.draw_pile_count = snapshot.draw_pile_uids.size()
	snapshot.hand_count = snapshot.hand_uids.size()
	snapshot.discard_pile_count = snapshot.discard_pile_uids.size()
	snapshot.summon_reserve_count = snapshot.summon_reserve_uids.size()
	snapshot.exhausted_count = snapshot.exhausted_uids.size()
	return snapshot


func prepare_draw(ctx: DrawContext) -> void:
	if rule_host != null:
		rule_host.prepare_draw(ctx)
	draw_prepare_requested.emit(ctx)


func after_draw(ctx: DrawContext) -> void:
	if rule_host != null:
		rule_host.after_draw(ctx)
	draw_completed.emit(ctx)


func prepare_discard(ctx: DiscardContext) -> void:
	if rule_host != null:
		rule_host.prepare_discard(ctx)
	discard_prepare_requested.emit(ctx)


func after_discard(ctx: DiscardContext) -> void:
	if rule_host != null:
		rule_host.after_discard(ctx)
	discard_completed.emit(ctx)


func prepare_hand_cleanup(ctx: HandCleanupContext) -> void:
	if rule_host != null:
		rule_host.prepare_hand_cleanup(ctx)
	hand_cleanup_prepare_requested.emit(ctx)


func after_hand_cleanup(ctx: HandCleanupContext) -> void:
	if rule_host != null:
		rule_host.after_hand_cleanup(ctx)
	hand_cleanup_completed.emit(ctx)


func _on_request_draw_cards(ctx: DrawContext) -> void:
	#print("[TRACE battle_card_bins] _on_request_draw_cards: ctx=%s reason=%s amount=%d" % [
		#str(ctx != null),
		#String(ctx.reason) if ctx != null else "",
		#int(ctx.amount) if ctx != null else -1
	#])
	await request_draw(ctx)

func _on_execute_discard_cards(ctx: DiscardContext) -> void:
	await request_discard(ctx)


func _ensure_event_connections() -> void:
	if Events == null:
		return
	if !Events.request_draw_cards.is_connected(_on_request_draw_cards):
		Events.request_draw_cards.connect(_on_request_draw_cards)
	if !Events.execute_discard_cards.is_connected(_on_execute_discard_cards):
		Events.execute_discard_cards.connect(_on_execute_discard_cards)


func is_hand_card_locked_until_next_player_turn(card_uid: String) -> bool:
	return bool(state.hand_locked_until_next_player_turn.get(String(card_uid), false))


func unlock_hand_cards_for_player_turn() -> void:
	if state.hand_locked_until_next_player_turn.is_empty():
		return
	state.hand_locked_until_next_player_turn.clear()


func _draw_cards_into_hand(ctx: DrawContext) -> Array[CardData]:
	var drawn: Array[CardData] = []
	var count := maxi(ctx.amount, 0)
	if count <= 0:
		return drawn
	if !_has_any_cards_available_to_draw():
		return drawn

	if !state.first_hand_drawn and ctx.use_first_hand_summon_guarantee:
		state.first_hand_drawn = true
		return _draw_first_hand_with_summon_guarantee(count)

	for _i in range(count):
		var card := _draw_one_from_draw_pile()
		if card == null:
			break
		state.hand_pile.add_back(card)
		drawn.append(card)
	return drawn


func _draw_first_hand_with_summon_guarantee(count: int) -> Array[CardData]:
	var drawn: Array[CardData] = []
	if count <= 0 or !_has_any_cards_available_to_draw():
		return drawn

	for _i in range(count):
		var card := _draw_one_from_draw_pile()
		if card == null:
			break
		drawn.append(card)

	var has_summon := false
	for card in drawn:
		if card != null and card.card_type == CardData.CardType.SUMMON:
			has_summon = true
			break

	if !has_summon and state.first_hand_summon_guarantee and !drawn.is_empty():
		var summon_indices: Array[int] = []
		for idx in range(state.draw_pile.cards.size()):
			var remaining: CardData = state.draw_pile.cards[idx]
			if remaining != null and remaining.card_type == CardData.CardType.SUMMON:
				summon_indices.append(idx)

		if !summon_indices.is_empty():
			var summon_choice_idx := _rng_range_i(0, summon_indices.size() - 1, "first_hand.summon_index")
			var draw_pile_idx := summon_indices[summon_choice_idx]
			var hand_idx := _rng_range_i(0, drawn.size() - 1, "first_hand.hand_index")
			var summon_card: CardData = state.draw_pile.cards[draw_pile_idx]
			state.draw_pile.cards[draw_pile_idx] = drawn[hand_idx]
			drawn[hand_idx] = summon_card

	for card in drawn:
		state.hand_pile.add_back(card)
	return drawn


func _draw_one_from_draw_pile() -> CardData:
	if !_has_any_cards_available_to_draw():
		return null
	if state.draw_pile.is_empty():
		_take_discards_into_draw()
		if !state.draw_pile.is_empty() and !_is_no_shuffle_mode():
			_shuffle_draw_pile()
	if state.draw_pile.is_empty():
		return null
	if _is_no_shuffle_mode():
		return state.draw_pile.draw_front()
	return state.draw_pile.draw_back()


func _has_any_cards_available_to_draw() -> bool:
	return state != null \
		and state.draw_pile != null \
		and state.discard_pile != null \
		and (!state.draw_pile.is_empty() or !state.discard_pile.is_empty())


func _take_discards_into_draw() -> void:
	if state.discard_pile.is_empty():
		return
	for card: CardData in state.discard_pile.cards:
		state.draw_pile.add_back(card)
	state.discard_pile.clear()


func _shuffle_draw_pile() -> void:
	_shuffle_pile_with_rng(state.draw_pile)
	state.draw_pile.card_pile_size_changed.emit(state.draw_pile.cards.size())

func _is_no_shuffle_mode() -> bool:
	if battle == null or battle.sim_host == null:
		return false
	var api := battle.sim_host.get_main_api()
	if api == null or api.state == null or api.state.resource == null:
		return false
	return int(api.state.resource.shuffle_mode) == int(ResourceState.ShuffleMode.NO_SHUFFLE)


func _shuffle_pile_with_rng(pile: CardPile) -> void:
	if pile == null or pile.cards.size() <= 1:
		return
	for i in range(pile.cards.size() - 1, 0, -1):
		var j := _rng_range_i(0, i, "shuffle.%d" % i)
		if i == j:
			continue
		var tmp := pile.cards[i]
		pile.cards[i] = pile.cards[j]
		pile.cards[j] = tmp


func _rng_range_i(lo: int, hi: int, tag: String) -> int:
	if rng == null:
		rng = RNG.new(1)
	return rng.debug_range_i(lo, hi, "battle_card_bins.%s" % tag)


func _get_bin_pile(kind: int) -> CardPile:
	match kind:
		CardMoveContext.BinKind.DRAW_PILE:
			return state.draw_pile
		CardMoveContext.BinKind.HAND:
			return state.hand_pile
		CardMoveContext.BinKind.DISCARD_PILE:
			return state.discard_pile
		CardMoveContext.BinKind.SUMMON_RESERVE:
			return state.summon_reserve_pile
		CardMoveContext.BinKind.EXHAUSTED:
			return state.exhausted_pile
		_:
			return null


func _remove_card_by_uid(pile: CardPile, uid: String) -> CardData:
	if pile == null or uid.is_empty():
		return null
	for idx in range(pile.cards.size()):
		var card: CardData = pile.cards[idx]
		if card == null:
			continue
		card.ensure_uid()
		if String(card.uid) == uid:
			var removed := pile.cards[idx]
			pile.cards.remove_at(idx)
			pile.card_pile_size_changed.emit(pile.cards.size())
			return removed
	return null


func _uids_for_cards(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for item in cards:
		var card := item as CardData
		if card == null:
			continue
		card.ensure_uid()
		out.append(String(card.uid))
	return out

func _clear_overload_on_cards(cards: Array[CardData]) -> void:
	for card in cards:
		if card == null:
			continue
		card.overload = 0

func _reduce_overload_for_cards(cards: Array[CardData], amount: int) -> void:
	var delta := maxi(int(amount), 0)
	if delta <= 0:
		return
	for card in cards:
		if card == null:
			continue
		card.overload = maxi(int(card.overload) - delta, 0)

func _set_summon_release_overload(cards: Array[CardData], overload_mod: int) -> void:
	for card in cards:
		if card == null or !_has_summon_effect(card):
			continue
		var overload: int = clampi(card.summon_release_overload + overload_mod, 0, 5)
		card.overload = overload

func _has_summon_effect(card: CardData) -> bool:
	if card == null:
		return false
	for action in card.actions:
		if action is SummonAction:
			return true
	return false

func _refresh_hand_cards() -> void:
	if hand == null:
		return
	hand.refresh_hand_cards()
