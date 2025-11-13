class_name CardReward extends ColorRect

signal card_reward_selected(card_data: CardData)

const MENU_CARD = preload("res://cards/menu_card/menu_card.tscn")

@export var card_choices: Array[CardData] : set = set_card_choices

@onready var card_choice_container: HBoxContainer = %CardChoiceContainer
@onready var skip_card: Button = %SkipCard
@onready var card_tooltip_popup: CardTooltipPopup = $CardTooltipPopup

@onready var take_button: Button = %TakeButton

var selected_card: CardData

func _ready() -> void:
	_clear_rewards()
	
	take_button.pressed.connect(
		func(): 
			card_reward_selected.emit(selected_card)
			#print("drafted %s" % selected_card.name)
			queue_free()
	)
	
	skip_card.pressed.connect(
		func():
			card_reward_selected.emit(null)
			#print("skipped card reward")
			queue_free()
	)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		card_tooltip_popup.hide_tooltip()

func _clear_rewards() -> void:
	for card: Node in card_choice_container.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	
	selected_card = null

func _show_tooltip(card: CardData) -> void:
	selected_card = card
	card_tooltip_popup.show_tooltip(card)

func set_card_choices(new_card_choices: Array[CardData]) -> void:
	card_choices = new_card_choices
	
	if !is_node_ready():
		await ready
	
	_clear_rewards()
	for card_data: CardData in card_choices:
		#print("card_reward.gd set_card_choices(): card choice is " + str(card_data))
		print("card_reward.gd Populating menu cards...", Time.get_ticks_msec())
		var new_card : MenuCard = MENU_CARD.instantiate() as MenuCard
		card_choice_container.add_child(new_card)
		new_card.card_data = card_data
		new_card.tooltip_requested.connect(_show_tooltip)
