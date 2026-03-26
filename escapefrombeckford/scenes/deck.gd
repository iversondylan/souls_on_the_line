# deck.gd

class_name Deck extends Node

signal draw_pile_size_changed(cards_amount)

var bins: BattleCardBins : set = _set_bins

var card_collection: CardPile = CardPile.new() : set = _set_card_collection

var _fallback_draw_pile: CardPile = CardPile.new()
var _fallback_discard_pile: CardPile = CardPile.new()
var _fallback_summon_reserve_by_uid: Dictionary = {}
var _fallback_first_shuffle: bool = true
var _fallback_first_hand_drawn: bool = false
var _fallback_first_hand_summon_guarantee: bool = true
var id_counter: int = 0

var draw_pile: CardPile:
	get:
		if bins != null and bins.state != null:
			return bins.state.draw_pile
		return _fallback_draw_pile

var discard_pile: CardPile:
	get:
		if bins != null and bins.state != null:
			return bins.state.discard_pile
		return _fallback_discard_pile

var summon_reserve_by_uid: Dictionary:
	get:
		if bins != null and bins.state != null:
			return bins.state.summon_reserve_by_uid
		return _fallback_summon_reserve_by_uid

var first_shuffle: bool:
	get:
		if bins != null and bins.state != null:
			return bins.state.first_shuffle
		return _fallback_first_shuffle
	set(value):
		if bins != null and bins.state != null:
			bins.state.first_shuffle = value
		else:
			_fallback_first_shuffle = value

var first_hand_drawn: bool:
	get:
		if bins != null and bins.state != null:
			return bins.state.first_hand_drawn
		return _fallback_first_hand_drawn
	set(value):
		if bins != null and bins.state != null:
			bins.state.first_hand_drawn = value
		else:
			_fallback_first_hand_drawn = value

var first_hand_summon_guarantee: bool:
	get:
		if bins != null and bins.state != null:
			return bins.state.first_hand_summon_guarantee
		return _fallback_first_hand_summon_guarantee
	set(value):
		if bins != null and bins.state != null:
			bins.state.first_hand_summon_guarantee = value
		else:
			_fallback_first_hand_summon_guarantee = value


func _set_bins(new_bins: BattleCardBins) -> void:
	bins = new_bins
	if bins != null and bins.state != null:
		bins.state.first_hand_summon_guarantee = _fallback_first_hand_summon_guarantee


func add_card(card_data: CardData) -> void:
	card_data.id = id_counter
	card_collection.add_back(card_data)
	card_data.id = id_counter
	id_counter += 1


func _set_card_collection(card_pile: CardPile) -> void:
	card_collection = card_pile
	id_counter = 0
	for card_data: CardData in card_collection.cards:
		card_data.id = id_counter
		id_counter += 1


func add_card_to_discard(card_data: CardData) -> void:
	if bins != null:
		bins.add_card_to_discard_for_compat(card_data)
		return
	_fallback_discard_pile.add_back(card_data)


func discard_summon_reserve_card(card_data: CardData) -> void:
	add_card_to_discard(card_data)


func draw_pile_is_empty() -> bool:
	return draw_pile.is_empty()


func reset() -> void:
	if bins != null:
		bins.reset_bins()
		return
	_fallback_draw_pile.clear()
	_fallback_discard_pile.clear()
	id_counter = 0
	_fallback_first_shuffle = true
	_fallback_first_hand_drawn = false


func clear_discard() -> void:
	discard_pile.clear()


func remove_card(card_id: int) -> void:
	card_collection.erase(card_id)


func get_discards() -> CardPile:
	return discard_pile.duplicate()


func get_draw_cards() -> CardPile:
	return draw_pile.duplicate()


func take_discards() -> void:
	if bins != null:
		bins.make_draw_pile()
		return
	if _fallback_discard_pile == null or _fallback_discard_pile.cards.is_empty():
		return
	for card: CardData in _fallback_discard_pile.cards:
		_fallback_draw_pile.add_back(card)
	_fallback_discard_pile.clear()


func make_draw_pile() -> void:
	if bins != null:
		bins.make_draw_pile()
		return
	if _fallback_first_shuffle:
		_fallback_draw_pile = card_collection.duplicate(true)
		_fallback_first_shuffle = false
	else:
		take_discards()
	shuffle()


func _generate_card_id(card_data: CardData) -> int:
	card_data.id = id_counter
	return id_counter


func draw_card() -> CardData:
	if bins != null:
		return bins.draw_card_from_pile_for_compat()

	if _fallback_draw_pile.is_empty():
		take_discards()
		shuffle()

	if _fallback_draw_pile.is_empty():
		push_error("Deck.draw_card(): No cards available to draw")
		return null

	var drawn_card := _fallback_draw_pile.draw_back()
	draw_pile_size_changed.emit(_fallback_draw_pile.cards.size())
	return drawn_card


func shuffle() -> void:
	draw_pile.shuffle()
	draw_pile.card_pile_size_changed.emit(draw_pile.cards.size())


func clear() -> void:
	draw_pile.clear()
	draw_pile_size_changed.emit(draw_pile.cards.size())


func reserve_summon_card(card_data: CardData) -> void:
	if card_data == null:
		return
	card_data.ensure_uid()
	if bins != null:
		bins.reserve_card_from_hand(card_data)
		return
	_fallback_summon_reserve_by_uid[String(card_data.uid)] = card_data


func discard_reserved_summon_card(card_uid: String) -> void:
	if card_uid == "":
		return
	if bins != null:
		bins.discard_reserved_summon_card(card_uid)
		return
	if !_fallback_summon_reserve_by_uid.has(card_uid):
		push_warning("Deck.discard_reserved_summon_card(): missing uid=%s" % card_uid)
		return
	var cd: CardData = _fallback_summon_reserve_by_uid[card_uid]
	_fallback_summon_reserve_by_uid.erase(card_uid)
	add_card_to_discard(cd)
