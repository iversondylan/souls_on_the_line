class_name Deck extends Node

signal draw_pile_size_changed(cards_amount)

var card_collection: CardPile : set = _set_card_collection
#@onready var card_pile := load("res://custom_resources/card_pile.gd")
#var collection_pile : CardPile = CardPile.new()
var draw_pile : CardPile = CardPile.new()
var discard_pile : CardPile = CardPile.new()
#var summon_reserve: CardPile
var id_counter : int# = 0
var first_shuffle: bool = true


func add_card(card_data: CardData): #change to CardData as input
	#var card_id = _generate_card_id(card_data)
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
	
#func add_card_pile(card_pile: CardPile) -> void:
	#for card: CardData in card_pile.cards:
		#add_card(card)

func add_card_to_discard(card_data: CardData):
	#if !ready:
		#await ready
	#card_collection[card_data.id].card_status = CardWithID.CardStatus.DISCARD_PILE
	discard_pile.add_back(card_data)

#func add_card_to_summon_reserve(card_with_id: CardWithID) -> void:
	#card_collection[card_with_id.id].card_status = CardWithID.CardStatus.SUMMON_RESERVE
	#summon_reserve.push_back(card_with_id)

func discard_summon_reserve_card(card_data: CardData) -> void:
	#summon_reserve.erase(card_with_id)
	add_card_to_discard(card_data)

func draw_pile_is_empty() -> bool:
	return draw_pile.is_empty()

func reset():
	draw_pile.clear()
	discard_pile.clear()
	id_counter = 0
	#for card in card_collection.values():
		#card.card_status = CardData.CardStatus.PRE_GAME
	first_shuffle = true

func clear_discard():
	discard_pile = null

func remove_card(card_id: int):
	card_collection.erase(card_id)

#func update_card(card_id: int, card_data: CardData):
	#card_collection[card_id].card_data = card_data

#func make_all_cards_from_collection() -> void:
	#draw_pile.clear()
	#if !GameRecord.deck.is_empty():
	#draw_pile = card_collection.duplicate()
	#for card : CardData in card_collection.values():
		#var duplicate_card: CardData = card.duplicate()
		#draw_pile.add_back(duplicate_card)
	
	#var cards := CardPile.new()
	#if !card_collection.is_empty():
		#for card : CardData in card_collection.values():
			#var duplicate_card: CardData = card.duplicate()
			#cards.add_back(duplicate_card)
			#duplicate_card.card_status = CardData.CardStatus.DRAW_PILE
	#return cards

func get_discards() -> CardPile:
	#var cards: Array[CardWithID] = []
	#if !discard_pile.is_empty():
		#for card in discard_pile:
			#cards.push_back(card)
	return discard_pile.duplicate()

func get_draw_cards() -> CardPile:
	#var cards: Array[CardWithID] = []
	#if !draw_pile.is_empty():
		#for card in draw_pile:
			#cards.push_back(card)
	return draw_pile.duplicate()

func take_discards() -> void:
	for card: CardData in discard_pile.cards:
		draw_pile.add_back(card)
	#var cards : CardPile = discard_pile.duplicate()
	#for card in discard_pile.cards:
		#card_collection[card_with_id.id].card_status = CardWithID.CardStatus.DRAW_PILE
		#cards_wtih_id.push_back(card_with_id)
	discard_pile.clear()
	#return cards

#func make_collection_pile() -> void:
	#collection_pile = GameRecord.deck.duplicate()
	

func make_draw_pile():
	if first_shuffle:
		draw_pile = card_collection.duplicate()
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
	var drawn_card: CardData = draw_pile.draw_back()
	#card_collection[drawn_card.id].card_status = CardWithID.CardStatus.HAND
	draw_pile_size_changed.emit(draw_pile.cards.size())
	return drawn_card

func shuffle() -> void:
	draw_pile.shuffle()

func clear() -> void:
	draw_pile.clear()
	draw_pile_size_changed.emit(draw_pile.cards.size())

#func peek_top() -> CardWithID:
	#return draw_pile.back()
#
#func put_card_on_top(card: CardWithID):
	#draw_pile.push_back(card)

#func _to_string() -> String:
	#var _card_strings: PackedStringArray = []
	#for i in range(draw_pile.size()):
		#_card_strings.push_back("%s: %s" % [i+1, draw_pile[i].id])
	#return "\n".join(_card_strings)
