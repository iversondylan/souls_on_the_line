class_name CardTooltipPopup extends Control

const MENU_CARD_SCENE := preload("uid://d4g7iin5x7648")

@export var background_color: Color = Color("0d11259e")

@onready var background: ColorRect = %Background

@onready var tooltip_card_container: CenterContainer = %TooltipCardContainer
@onready var card_description: RichTextLabel = %CardDescription

var player_data: PlayerData
var api: SimBattleAPI
var show_battle_modifications := false

func _ready() -> void:
	for card: MenuCard in tooltip_card_container.get_children():
		card.queue_free()
	background.color = background_color

func show_tooltip(card: CardData) -> void:
	var new_card := MENU_CARD_SCENE.instantiate() as MenuCard
	new_card.api = api
	new_card.show_battle_modifications = show_battle_modifications
	tooltip_card_container.add_child(new_card)
	new_card.card_data = card
	new_card.set_card_data(card)
	new_card.tooltip_requested.connect(hide_tooltip.unbind(1))
	card_description.text = new_card.get_description()
	show()

func hide_tooltip() -> void:
	if !visible:
		return
	
	for card: MenuCard in tooltip_card_container.get_children():
		card.queue_free()
	
	hide()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		hide_tooltip()
