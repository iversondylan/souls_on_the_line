class_name Shop extends Control

const SHOP_CARD_SCN = preload("uid://bsiw7kxq3vytd")
const SHOP_ARCANUM_SCN = preload("uid://6rwtjllgr66t")

@export var shop_arcana: Arcana
@export var player_data: PlayerData
@export var run_state: RunState
var arcana_system: ArcanaSystem

@onready var card_container: HBoxContainer = %Cards
@onready var arcanum_container: HBoxContainer = %Arcana
@onready var shopkeeper_animation: AnimationPlayer = %ShopkeeperAnimation
@onready var blink_timer: Timer = %BlinkTimer
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup

var run: Run
var arcana_reward_pool: ArcanaRewardPool
var arcana_catalog: ArcanaCatalog

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
	ctx.card_offer_costs = []
	for _i in ctx.card_offers.size():
		ctx.card_offer_costs.append(100)
	ctx.arcanum_offers = _build_shop_arcanum_offers()
	ctx.arcanum_offer_costs = []
	for _i in ctx.arcanum_offers.size():
		ctx.arcanum_offer_costs.append(100)
	if arcana_system != null:
		arcana_system.on_shop_context_started(ctx)
	return ctx

func populate_from_context(ctx: ShopContext) -> void:
	if ctx == null:
		return
	_clear_shop_items()
	_populate_shop_cards(ctx.card_offers, ctx.card_offer_costs, ctx.claimed_card_offer_indices)
	_populate_shop_arcana(ctx.arcanum_offers, ctx.arcanum_offer_costs, ctx.claimed_arcanum_offer_indices)

func _clear_shop_items() -> void:
	for shop_card: ShopCard in card_container.get_children():
		shop_card.queue_free()
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.queue_free()

func _build_shop_card_offers() -> Array[CardData]:
	var shop_cards: Array[CardData] = []
	var source_pile := run_state.draftable_cards if run_state != null and run_state.draftable_cards != null else player_data.draftable_cards
	if source_pile == null:
		return shop_cards
	var available_cards := source_pile.cards.duplicate(true)
	available_cards.shuffle()
	var cards_added: int = 0
	for card: CardData in available_cards:
		if card:
			cards_added += 1
			shop_cards.append(card)
		if cards_added >= 3:
			break
	return shop_cards

func _populate_shop_cards(shop_cards: Array[CardData], costs: Array[int] = [], claimed_indices: Array[int] = []) -> void:
	for i in range(shop_cards.size()):
		if claimed_indices.has(i):
			continue
		var card_data: CardData = shop_cards[i]
		var new_shop_card := SHOP_CARD_SCN.instantiate() as ShopCard
		card_container.add_child(new_shop_card)
		new_shop_card.card_data = card_data
		new_shop_card.offer_index = i
		var cost := costs[i] if i < costs.size() else 100
		new_shop_card.original_gold_cost = cost
		new_shop_card.gold_cost = cost
		new_shop_card.current_menu_card.tooltip_requested.connect(card_tooltip_popup.show_tooltip)
		new_shop_card.update(run_state)

func _build_shop_arcanum_offers() -> Array[Arcanum]:
	var eligible_arcana: Array[Arcanum] = []
	print("_generate_shop_arcana()")
	for arcanum_id: String in arcana_reward_pool.allowed_ids:
		print("_generate_shop_arcana() arcanum_id: %s" % arcanum_id)
	for arcanum: Arcanum in arcana_catalog.arcana:
		print("shop.gd _generate_shop_arcana() looping arcana: %s" % arcanum.get_id())
		if is_arcanum_eligible(arcanum):
			eligible_arcana.append(arcanum)

	if eligible_arcana.is_empty():
		print("shop.gd _generate_shop_arcana() arcana empty" % eligible_arcana)
		return []
	eligible_arcana.shuffle()
	return eligible_arcana.slice(0, 3)

func _populate_shop_arcana(shop_arcana: Array[Arcanum], costs: Array[int] = [], claimed_indices: Array[int] = []) -> void:
	for i in range(shop_arcana.size()):
		if claimed_indices.has(i):
			continue
		var arcanum: Arcanum = shop_arcana[i]
		var shop_arcanum := SHOP_ARCANUM_SCN.instantiate() as ShopArcanum
		arcanum_container.add_child(shop_arcanum)
		shop_arcanum.arcanum = arcanum
		shop_arcanum.offer_index = i
		var cost := costs[i] if i < costs.size() else 100
		shop_arcanum.original_gold_cost = cost
		shop_arcanum.gold_cost = cost
		shop_arcanum.update(run_state)

func _update_items() -> void:
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.update(run_state)
	for shop_card: ShopCard in card_container.get_children():
		shop_card.update(run_state)

func _on_back_button_pressed() -> void:
	Events.shop_exited.emit()

func _on_shop_card_bought(card_data: CardData, gold_cost: int, offer_index: int) -> void:
	run_state.run_deck.add_card(card_data)
	run_state.gold -= gold_cost
	if !run_state.pending_shop_claimed_card_offer_indices.has(offer_index):
		run_state.pending_shop_claimed_card_offer_indices.append(offer_index)
	_update_items()
	if run != null:
		run._persist_active_run()

func _on_shop_arcanum_bought(arcanum: Arcanum, gold_cost: int, offer_index: int) -> void:
	arcana_system.add_arcanum(arcanum)
	run_state.gold -= gold_cost
	if !run_state.pending_shop_claimed_arcanum_offer_indices.has(offer_index):
		run_state.pending_shop_claimed_arcanum_offer_indices.append(offer_index)
	_update_items()
	if run != null:
		run._persist_active_run()

func is_arcanum_eligible(arcanum: Arcanum) -> bool:
	if arcanum.starter_arcanum:
		print("it's a starter")
		return false
	##Note
	##If performance ever matters:
	##replace Array.has() with Dictionary or Set
	if !arcana_reward_pool.allowed_ids.has(arcanum.get_id()):
		print("it's not in arcana_reward_pool.allowed_ids")
		return false
	if arcana_system.has_arcanum(arcanum.get_id()):
		print("the arcana system already has it")
		return false
	print("it's eligible")
	return true
