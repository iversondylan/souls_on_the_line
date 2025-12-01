class_name Shop extends Control

const SHOP_CARD_SCN = preload("res://scenes/shop/shop_card.tscn")
const SHOP_ARCANUM_SCN = preload("res://scenes/shop/shop_arcanum.tscn")

@export var shop_arcana: Arcana
@export var player_data: PlayerData
@export var run_account: RunAccount
@export var arcana_system: ArcanaSystem

@onready var card_container: HBoxContainer = %Cards
@onready var arcanum_container: HBoxContainer = %Arcana
@onready var shopkeeper_animation: AnimationPlayer = %ShopkeeperAnimation
@onready var blink_timer: Timer = %BlinkTimer
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup
@onready var modifier_system: ModifierSystem = $ModifierSystem



func _ready() -> void:
	for shop_card: ShopCard in card_container.get_children():
		shop_card.queue_free()
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.queue_free()
	
	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.shop_arcanum_bought.connect(_on_shop_arcanum_bought)
	
	_blink_timer_setup()
	blink_timer.timeout.connect(_on_blink_timer_timeout)
	

func _blink_timer_setup() -> void:
	blink_timer.wait_time = randf_range(1.0, 5.0)
	blink_timer.start()

func _on_blink_timer_timeout() -> void:
	shopkeeper_animation.play("blink")
	_blink_timer_setup()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and card_tooltip_popup.visible:
		card_tooltip_popup.hide_tooltip()

func populate_shop() -> void:
	_generate_shop_cards()
	_generate_shop_arcana()

func _generate_shop_cards() -> void:
	var shop_cards: Array[CardData] = []
	var available_cards := player_data.draftable_cards.cards.duplicate(true)
	available_cards.shuffle()
	shop_cards = available_cards.slice(0, 3)
	
	for card_data: CardData in shop_cards:
		var new_shop_card := SHOP_CARD_SCN.instantiate() as ShopCard
		card_container.add_child(new_shop_card)
		new_shop_card.card_data = card_data
		new_shop_card.current_menu_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)
		new_shop_card.gold_cost = _get_updated_shop_cost(new_shop_card.gold_cost)
		new_shop_card.update(run_account)

func _generate_shop_arcana() -> void:
	var shop_arcanaz: Array[Arcanum] = []
	var available_arcana := player_data.possible_arcana.arcana.filter(
		func(arcanum: Arcanum):
			return !arcana_system.has_arcanum(arcanum.id)
	) as Array[Arcanum]
	available_arcana.shuffle()
	shop_arcanaz = available_arcana.slice(0, 3)
	
	for arcanum: Arcanum in shop_arcanaz:
		var new_shop_arcanum := SHOP_ARCANUM_SCN.instantiate() as ShopArcanum
		arcanum_container.add_child(new_shop_arcanum)
		new_shop_arcanum.arcanum = arcanum
		new_shop_arcanum.gold_cost = _get_updated_shop_cost(new_shop_arcanum.gold_cost)
		new_shop_arcanum.update(run_account)

func _get_updated_shop_cost(orig_cost: int) -> int:
	return modifier_system.get_modified_value(orig_cost, Modifier.Type.SHOP_COST)

func _update_items() -> void:
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.update(run_account)
	for shop_card: ShopCard in card_container.get_children():
		shop_card.update(run_account)

func _on_back_button_pressed() -> void:
	Events.shop_exited.emit()

func _on_shop_card_bought(card_data: CardData, gold_cost: int) -> void:
	run_account.deck.add_card(card_data)
	run_account.gold -= gold_cost
	_update_items()

func _on_shop_arcanum_bought(arcanum: Arcanum, gold_cost: int) -> void:
	arcana_system.add_arcanum(arcanum)
	run_account.gold -= gold_cost
	_update_items()
