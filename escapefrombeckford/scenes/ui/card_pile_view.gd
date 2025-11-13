class_name CardPileView extends Control

const MENU_CARD_SCENE := preload("res://cards/menu_card/menu_card.tscn")

@export var card_pile: CardPile

@onready var title: Label = %Title
@onready var card_grid: GridContainer = %CardGrid
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup
@onready var back_button: Button = %BackButton

var deck: Deck

func _ready() -> void:
	back_button.pressed.connect(hide)
	
	for card: Node in card_grid.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	
	#await get_tree().create_timer(1.5).timeout
	#card_pile = preload("res://fighters/Player/cole_basic_deck.tres")
	#show_current_view("Deck", true)

func _input(event: InputEvent) -> void:
	if event.is_action("ui_cancel"):
		if card_tooltip_popup.visible:
			card_tooltip_popup.hide_tooltip()
		else:
			hide()
#I DON'T SEE WHY THE FOLLOWING 3 FUNCTIONS CAN'T BE ELIMINATED. THESE CARD
#PILE VIEWS ALREADY GET ASSIGNED THEIR RESPECTIVE CARD PILES ELSEWHERE.
#I COULD JUST CALL show_current_view() INSTEAD.
func show_current_collection_view(new_title: String, randomized: bool = false) -> void:
	card_pile = deck.card_collection
	show_current_view(new_title, randomized)

func show_current_draw_view(new_title: String, randomized: bool = false) -> void:
	card_pile = deck.draw_pile
	show_current_view(new_title, randomized)

func show_current_discard_view(new_title: String, randomized: bool = false) -> void:
	card_pile = deck.discard_pile
	show_current_view(new_title, randomized)

func show_current_view(new_title: String, randomized: bool = false) -> void:
	for card: Node in card_grid.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	title.text = new_title
	_update_view.call_deferred(randomized)

func _update_view(randomized: bool) -> void:
	if !card_pile:
		return
	
	var all_cards := card_pile.cards.duplicate()
	if randomized:
		all_cards.shuffle()
	
	for card: CardData in all_cards:
		print("card_pile_view Populating menu cards...", Time.get_ticks_msec())
		var new_card := MENU_CARD_SCENE.instantiate() as MenuCard
		card_grid.add_child(new_card)
		new_card.card_data = card
		new_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)
	
	show()
