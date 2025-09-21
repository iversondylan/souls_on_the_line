class_name CardPileOpener extends TextureButton

@export var counter: Label
@export var card_pile: CardPile : set = _set_card_pile
#var deck: Deck

func _set_card_pile(_card_pile: CardPile) -> void:
	card_pile = _card_pile
	
	if !card_pile.card_pile_size_changed.is_connected(_on_card_pile_size_changed):
		print("card_pile_opener.gd CONNECTING NEW CARD PILE OF %s" % name)
		card_pile.card_pile_size_changed.connect(_on_card_pile_size_changed)
		_on_card_pile_size_changed(card_pile.cards.size())

func _on_card_pile_size_changed(n_cards: int) -> void:
	print("CHANGING %s TO CARD PILE SIZE OF %s" % [name, str(n_cards)])
	counter.text = str(n_cards)
