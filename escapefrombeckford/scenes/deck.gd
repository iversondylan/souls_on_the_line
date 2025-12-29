class_name Deck extends Node

signal draw_pile_size_changed(cards_amount)

var card_collection: CardPile : set = _set_card_collection
var draw_pile : CardPile = CardPile.new()
var discard_pile : CardPile = CardPile.new()
var id_counter : int# = 0
var first_shuffle: bool = true


func add_card(card_data: CardData):
	card_data.card_status = CardData.CardStatus.PRE_GAME
	card_data.id = id_counter
	card_collection.add_back(card_data)
	card_data.id = id_counter
	id_counter += 1

func _set_card_collection(_card_pile: CardPile) -> void:
	card_collection = _card_pile
	id_counter = 0
	for card_data: CardData in card_collection.cards:
		card_data.id = id_counter
		id_counter += 1

func add_card_to_discard(card_data: CardData):
	discard_pile.add_back(card_data)

func discard_summon_reserve_card(card_data: CardData) -> void:
	add_card_to_discard(card_data)

func draw_pile_is_empty() -> bool:
	return draw_pile.is_empty()

func reset():
	draw_pile.clear()
	discard_pile.clear()
	id_counter = 0
	first_shuffle = true

func clear_discard():
	discard_pile = null

func remove_card(card_id: int):
	card_collection.erase(card_id)

func get_discards() -> CardPile:
	return discard_pile.duplicate()

func get_draw_cards() -> CardPile:
	return draw_pile.duplicate()

func take_discards() -> void:
	for card: CardData in discard_pile.cards:
		draw_pile.add_back(card)
	discard_pile.clear()

func make_draw_pile():
	if first_shuffle:
		draw_pile = card_collection.duplicate(true)
		first_shuffle = false
	else:
		take_discards()
	shuffle()

func _generate_card_id(_card_data: CardData):
	_card_data.id = id_counter
	return id_counter

func draw_card() -> CardData:
	if draw_pile_is_empty():
		take_discards()
		shuffle()

	if draw_pile_is_empty():
		push_error("Deck.draw_card(): No cards available to draw")
		return null

	var drawn_card := draw_pile.draw_back()
	draw_pile_size_changed.emit(draw_pile.cards.size())
	return drawn_card

func shuffle() -> void:
	draw_pile.shuffle()

func clear() -> void:
	draw_pile.clear()
	draw_pile_size_changed.emit(draw_pile.cards.size())
