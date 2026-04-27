class_name CardPileView extends Control

const MENU_CARD_SCENE := preload("uid://d4g7iin5x7648")

@export var card_pile: CardPile
@export var show_battle_modifications := false

@onready var title: Label = %Title
@onready var card_grid: GridContainer = %CardGrid
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup
@onready var back_button: Button = %BackButton

var player_data: PlayerData
var api: SimBattleAPI

func _ready() -> void:
	back_button.pressed.connect(hide)
	if show_battle_modifications:
		Events.modify_battle_card.connect(_on_modify_battle_card)
	
	for card: Node in card_grid.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	
	#await get_tree().create_timer(1.5).timeout
	#card_pile = preload("uid://gsb7q5fcn68v")
	#show_current_view("Collection", true)

func _input(event: InputEvent) -> void:
	if event.is_action("ui_cancel"):
		if card_tooltip_popup.visible:
			card_tooltip_popup.hide_tooltip()
		else:
			hide()
func show_current_view(new_title: String, randomized: bool = false) -> void:
	for card: Node in card_grid.get_children():
		card.queue_free()
	
	card_tooltip_popup.hide_tooltip()
	card_tooltip_popup.api = api if show_battle_modifications else null
	card_tooltip_popup.show_battle_modifications = show_battle_modifications
	title.text = new_title
	_update_view.call_deferred(randomized)

func _update_view(randomized: bool) -> void:
	if !card_pile:
		return
	
	var all_cards := card_pile.cards.duplicate()
	if randomized:
		all_cards.shuffle()
	
	for card: CardData in all_cards:
		var new_card := MENU_CARD_SCENE.instantiate() as MenuCard
		new_card.player_data = player_data
		new_card.api = api
		new_card.show_battle_modifications = show_battle_modifications
		card_grid.add_child(new_card)
		new_card.set_card_data(card)
		
		new_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)
	
	show()


func _on_modify_battle_card(card_uid: String, _modified_fields: Dictionary, _reason: String) -> void:
	if !show_battle_modifications:
		return
	for child in card_grid.get_children():
		var card := child as MenuCard
		if card == null or card.card_data == null:
			continue
		if String(card.card_data.uid) != String(card_uid):
			continue
		card.refresh_battle_visuals()
