class_name CardsViewWindow extends Node2D

@onready var card_container_scn: PackedScene = preload("res://ui/card_container.tscn")
#@onready var usable_card_scn: PackedScene = preload("res://cards/UsableCard.tscn")
@onready var flow_container = $ScrollContainer/HFlowContainer

var cached_card_containers: Array[CardContainer] = []

func _ready() -> void:
	$ColorRect.set_size($ScrollContainer.size)
	$ColorRect.set_position($ScrollContainer.position)

func clear_display():
	for child in flow_container.get_children():
		#child.remove_child(child.usable_card)
		flow_container.remove_child(child)
	for card_container in cached_card_containers:
		card_container.clear_card()
		#child.queue_free()
		
func show_window(cards: CardPile):
	display_card_list(cards)
	visible = true

func hide_window():
	visible = false

func display_card_list(cards: CardPile):
	clear_display()
	while cached_card_containers.size() < cards.cards.size():
		cached_card_containers.push_back(card_container_scn.instantiate() as CardContainer)
	
	for i in cards.cards.size():
		var card : CardData = cards.cards[i] as CardData
		var card_container: CardContainer = cached_card_containers[i]

		flow_container.add_child(card_container)
		card_container.card_data = card
