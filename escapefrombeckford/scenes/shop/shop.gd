class_name Shop extends Control

const SHOP_CARD_SCN = preload("res://scenes/shop/shop_card.tscn")
const SHOP_ARCANUM_SCN = preload("res://scenes/shop/shop_arcanum.tscn")

@export var shop_arcana: Arcana
@export var player_data: PlayerData
@export var run_state: RunState
var arcana_system: ArcanaSystem

@onready var card_container: HBoxContainer = %Cards
@onready var arcanum_container: HBoxContainer = %Arcana
@onready var shopkeeper_animation: AnimationPlayer = %ShopkeeperAnimation
@onready var blink_timer: Timer = %BlinkTimer
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup

var modifier_system: ModifierSystem

var run: Run: set = _set_run
var arcana_reward_pool: ArcanaRewardPool
var arcana_catalog: ArcanaCatalog

func _set_run(value) -> void:
		run = value
		if modifier_system:
			modifier_system.run = run

func _ready() -> void:
	if !modifier_system:
		modifier_system = ModifierSystem.new(self)
	for shop_card: ShopCard in card_container.get_children():
		shop_card.queue_free()
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.queue_free()
	
	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.shop_arcanum_bought.connect(_on_shop_arcanum_bought)
	modifier_system.modifier_changed.connect(_recalculate_prices)
	
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
	var ctx := build_opening_context()
	populate_from_context(ctx)

func build_opening_context() -> ShopContext:
	var ctx := ShopContext.new()
	ctx.run = run
	ctx.run_state = run_state
	ctx.player_data = player_data
	ctx.arcana_system = arcana_system
	ctx.arcana_catalog = arcana_catalog
	ctx.arcana_reward_pool = arcana_reward_pool
	ctx.card_offers = _build_shop_card_offers()
	ctx.arcanum_offers = _build_shop_arcanum_offers()
	return ctx

func populate_from_context(ctx: ShopContext) -> void:
	if ctx == null:
		return
	_clear_shop_items()
	_populate_shop_cards(ctx.card_offers)
	_populate_shop_arcana(ctx.arcanum_offers)

func _clear_shop_items() -> void:
	for shop_card: ShopCard in card_container.get_children():
		shop_card.queue_free()
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.queue_free()

func _build_shop_card_offers() -> Array[CardData]:
	var shop_cards: Array[CardData] = []
	var available_cards := player_data.draftable_cards.cards.duplicate(true)
	available_cards.shuffle()
	var cards_added: int = 0
	for card: CardData in available_cards:
		if card:
			cards_added += 1
			shop_cards.append(card)
		if cards_added >= 3:
			break
	return shop_cards

func _populate_shop_cards(shop_cards: Array[CardData]) -> void:
	for card_data: CardData in shop_cards:
		var new_shop_card := SHOP_CARD_SCN.instantiate() as ShopCard
		card_container.add_child(new_shop_card)
		new_shop_card.card_data = card_data
		new_shop_card.current_menu_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)
		new_shop_card.gold_cost = _get_updated_shop_cost(new_shop_card.gold_cost)
		new_shop_card.update(run_state)

func _build_shop_arcanum_offers() -> Array[Arcanum]:
	var eligible_arcana: Array[Arcanum] = []
	print("_generate_shop_arcana()")
	for arcanum_id: String in arcana_reward_pool.allowed_ids:
		print("_generate_shop_arcana() arcanum_id: %s" % arcanum_id)
	for arcanum: Arcanum in arcana_catalog.arcana:
		print("shop.gd _generate_shop_arcana() looping arcana: %s" % arcanum.id)
		if is_arcanum_eligible(arcanum):
			eligible_arcana.append(arcanum)

	if eligible_arcana.is_empty():
		print("shop.gd _generate_shop_arcana() arcana empty" % eligible_arcana)
		return []
	#print("shop.gd _generate_shop_arcana() eligible_arcana: %s" % eligible_arcana)
	eligible_arcana.shuffle()
	return eligible_arcana.slice(0, 3)

func _populate_shop_arcana(shop_arcana: Array[Arcanum]) -> void:
	for arcanum: Arcanum in shop_arcana:
		var shop_arcanum := SHOP_ARCANUM_SCN.instantiate() as ShopArcanum
		arcanum_container.add_child(shop_arcanum)
		shop_arcanum.arcanum = arcanum
		shop_arcanum.gold_cost = _get_updated_shop_cost(shop_arcanum.gold_cost)
		shop_arcanum.update(run_state)
	#var shop_arcanaz: Array[Arcanum] = []
	#var available_arcana := player_data.possible_arcana.arcana.filter(
		#func(arcanum: Arcanum):
			#return !arcana_system.has_arcanum(arcanum.id)
	#) as Array[Arcanum]
	#available_arcana.shuffle()
	#shop_arcanaz = available_arcana.slice(0, 3)
	#
	#for arcanum: Arcanum in shop_arcanaz:
		#var new_shop_arcanum := SHOP_ARCANUM_SCN.instantiate() as ShopArcanum
		#arcanum_container.add_child(new_shop_arcanum)
		#new_shop_arcanum.arcanum = arcanum
		#new_shop_arcanum.gold_cost = _get_updated_shop_cost(new_shop_arcanum.gold_cost)
		#new_shop_arcanum.update(run_state)

#func get_modifier_tokens() -> Array[ModifierToken]:
	#if arcana_system:
		#return arcana_system.get_modifier_tokens()
	#return []

func _get_updated_shop_cost(orig_cost: int) -> int:
	return modifier_system.get_modified_value(orig_cost, Modifier.Type.SHOP_COST)

func _update_items() -> void:
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.update(run_state)
	for shop_card: ShopCard in card_container.get_children():
		shop_card.update(run_state)

func _recalculate_prices() -> void:
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.gold_cost = _get_updated_shop_cost(shop_arcanum.original_gold_cost)
		shop_arcanum.update(run_state)
	for shop_card: ShopCard in card_container.get_children():
		shop_card.gold_cost = _get_updated_shop_cost(shop_card.original_gold_cost)
		shop_card.update(run_state)

func _on_back_button_pressed() -> void:
	Events.shop_exited.emit()

func _on_shop_card_bought(card_data: CardData, gold_cost: int) -> void:
	run_state.run_deck.add_card(card_data)
	run_state.gold -= gold_cost
	_update_items()
	if run != null:
		run._persist_active_run()

func _on_shop_arcanum_bought(arcanum: Arcanum, gold_cost: int) -> void:
	arcana_system.add_arcanum(arcanum)
	run_state.gold -= gold_cost
	_update_items()
	if run != null:
		run._persist_active_run()

func on_modifier_tokens_changed(mod_type: Modifier.Type) -> void:
	modifier_system.mark_dirty(mod_type)

func is_arcanum_eligible(arcanum: Arcanum) -> bool:
	if arcanum.starter_arcanum:
		print("it's a starter")
		return false
	##Note
	##If performance ever matters:
	##replace Array.has() with Dictionary or Set
	if !arcana_reward_pool.allowed_ids.has(arcanum.id):
		print("it's not in arcana_reward_pool.allowed_ids")
		return false
	if arcana_system.has_arcanum(arcanum.id):
		print("the arcana system already has it")
		return false
	print("it's eligible")
	return true
