class_name ShopCard extends VBoxContainer

const MENU_CARD_SCN = preload("uid://d4g7iin5x7648")
const SOLD_TEXT := "Sold"
const BUY_TEXT := "Buy"
const SOLD_FONT_COLOR := Color(0.65, 0.65, 0.65, 1.0)

@export var card_data: CardData : set = _set_card

@onready var card_container: CenterContainer = %CardContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@export var offer_index: int = -1
@export var original_gold_cost: int = 100
var gold_cost: int = 100
var is_claimed: bool = false

var current_menu_card: MenuCard
var _last_run_state: RunState

func update(run_state: RunState) -> void:
	if !card_container or !price or !buy_button:
		return

	_last_run_state = run_state
	_refresh_state()


func set_claimed(claimed: bool) -> void:
	is_claimed = claimed
	if !is_node_ready():
		return
	_refresh_state()


func _refresh_state() -> void:
	price_label.text = str(gold_cost)

	if is_claimed:
		price_label.add_theme_color_override("font_color", SOLD_FONT_COLOR)
		buy_button.text = SOLD_TEXT
		buy_button.disabled = true
		return

	buy_button.text = BUY_TEXT
	if _last_run_state != null and _last_run_state.gold >= gold_cost:
		price_label.remove_theme_color_override("font_color")
		buy_button.disabled = false
	else:
		price_label.add_theme_color_override("font_color", Color.RED)
		buy_button.disabled = true

func _set_card(new_card_data: CardData) -> void:
	if !is_node_ready():
		await ready
	
	card_data = new_card_data
	
	for menu_card: MenuCard in card_container.get_children():
		menu_card.queue_free()
	
	var new_menu_card := MENU_CARD_SCN.instantiate() as MenuCard
	card_container.add_child(new_menu_card)
	new_menu_card.set_card_data(new_card_data)
	current_menu_card = new_menu_card

func _on_buy_button_pressed() -> void:
	Events.shop_card_bought.emit(card_data, gold_cost, offer_index)
