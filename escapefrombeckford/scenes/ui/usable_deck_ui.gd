class_name UsableDeckUI extends TextureButton

var deck: Deck

func draw_card() -> CardData:
	return deck.draw_card()

func shuffle():
	deck.shuffle()
