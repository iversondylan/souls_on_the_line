class_name UsableDeckUI extends TextureButton

var run_deck: RunDeck

func draw_card() -> CardData:
	if run_deck == null or run_deck.card_collection == null:
		return null
	return run_deck.card_collection.draw_back()

func shuffle():
	if run_deck == null or run_deck.card_collection == null:
		return
	run_deck.card_collection.shuffle()
