class_name Shop extends Control

const SHOP_CARD_SCN = preload("uid://bsiw7kxq3vytd")
const SHOP_ARCANUM_SCN = preload("uid://6rwtjllgr66t")
const CARD_SELECTION_OVERLAY := preload("res://run/ui/card_selection_overlay.tscn")
const CONFIRMATION_PROMPT_SCN := preload("res://ui/confirmation_prompt.tscn")
const SHOP_GRID_COLUMNS := 3

@export var shop_arcana: Arcana
@export var player_data: PlayerData
@export var run_state: RunState
var arcana_system: ArcanaSystem
var arcana_system_container: ArcanaSystemContainer

@onready var ui_layer: CanvasLayer = %UILayer
@onready var card_container: GridContainer = %Cards
@onready var arcanum_container: GridContainer = %Arcana
@onready var shopkeeper_animation: AnimationPlayer = %ShopkeeperAnimation
@onready var blink_timer: Timer = %BlinkTimer
@onready var card_tooltip_popup: CardTooltipPopup = %CardTooltipPopup

var run: Run
var arcana_reward_pool: ArcanaRewardPool
var arcana_catalog: ArcanaCatalog
var _confirm_dialog
var _slot_replace_overlay: CardSelectionOverlay
var _pending_shop_card: CardData
var _pending_shop_slot_index: int = -1
var _pending_shop_gold_cost: int = 0
var _pending_shop_offer_index: int = -1

func _ready() -> void:
	for shop_card: ShopCard in card_container.get_children():
		shop_card.queue_free()
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.queue_free()
	
	Events.shop_card_bought.connect(_on_shop_card_bought)
	Events.shop_arcanum_bought.connect(_on_shop_arcanum_bought)
	_build_confirm_dialog()
	
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
	card_container.columns = SHOP_GRID_COLUMNS
	for i in range(shop_cards.size()):
		var card_data: CardData = shop_cards[i]
		var new_shop_card := SHOP_CARD_SCN.instantiate() as ShopCard
		card_container.add_child(new_shop_card)
		new_shop_card.card_data = card_data
		new_shop_card.offer_index = i
		var cost := costs[i] if i < costs.size() else 100
		new_shop_card.original_gold_cost = cost
		new_shop_card.gold_cost = cost
		new_shop_card.set_claimed(claimed_indices.has(i))
		if new_shop_card.current_menu_card != null:
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

func _populate_shop_arcana(_shop_arcana: Array[Arcanum], costs: Array[int] = [], claimed_indices: Array[int] = []) -> void:
	arcanum_container.columns = SHOP_GRID_COLUMNS
	for i in range(_shop_arcana.size()):
		var arcanum: Arcanum = _shop_arcana[i]
		var shop_arcanum := SHOP_ARCANUM_SCN.instantiate() as ShopArcanum
		arcanum_container.add_child(shop_arcanum)
		shop_arcanum.arcanum = arcanum
		shop_arcanum.offer_index = i
		var cost := costs[i] if i < costs.size() else 100
		shop_arcanum.original_gold_cost = cost
		shop_arcanum.gold_cost = cost
		shop_arcanum.set_claimed(claimed_indices.has(i))
		shop_arcanum.update(run_state)

func _update_items() -> void:
	for shop_arcanum: ShopArcanum in arcanum_container.get_children():
		shop_arcanum.set_claimed(_is_arcanum_offer_claimed(shop_arcanum.offer_index))
		shop_arcanum.update(run_state)
	for shop_card: ShopCard in card_container.get_children():
		shop_card.set_claimed(_is_card_offer_claimed(shop_card.offer_index))
		shop_card.update(run_state)

func _on_back_button_pressed() -> void:
	Events.shop_exited.emit()

func _on_shop_card_bought(card_data: CardData, gold_cost: int, offer_index: int) -> void:
	if card_data == null or run_state == null or run_state.run_deck == null:
		return
	if _is_card_offer_claimed(offer_index):
		return
	if card_data.is_soulbound_slot_card() and run_state.run_deck.has_soulbound_roster_enabled():
		_pending_shop_slot_index = -1
		_pending_shop_card = card_data
		_pending_shop_gold_cost = gold_cost
		_pending_shop_offer_index = offer_index
		_show_soulbound_slot_overlay()
		return
	run_state.run_deck.add_normal_card(card_data)
	run_state.gold -= gold_cost
	if !run_state.pending_shop_claimed_card_offer_indices.has(offer_index):
		run_state.pending_shop_claimed_card_offer_indices.append(offer_index)
	_update_items()
	if run != null:
		run._persist_active_run()

func _on_shop_arcanum_bought(arcanum: Arcanum, gold_cost: int, offer_index: int) -> void:
	if arcana_system_container == null or run_state == null or _is_arcanum_offer_claimed(offer_index):
		return
	arcana_system_container.add_arcanum(arcanum)
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


func _build_confirm_dialog() -> void:
	_confirm_dialog = CONFIRMATION_PROMPT_SCN.instantiate()
	if _confirm_dialog == null:
		return
	_confirm_dialog.confirmed.connect(_confirm_shop_soulbound_purchase)
	_confirm_dialog.canceled.connect(_clear_pending_shop_purchase)
	_get_modal_parent().add_child(_confirm_dialog)


func _show_soulbound_slot_overlay() -> void:
	if run_state == null or run_state.run_deck == null or !run_state.run_deck.has_soulbound_roster_enabled():
		return
	if is_instance_valid(_slot_replace_overlay):
		_slot_replace_overlay.queue_free()
	_slot_replace_overlay = CARD_SELECTION_OVERLAY.instantiate() as CardSelectionOverlay
	_get_modal_parent().add_child(_slot_replace_overlay)
	_slot_replace_overlay.selection_confirmed.connect(_on_shop_slot_selected)
	_slot_replace_overlay.selection_canceled.connect(_on_shop_slot_selection_canceled)
	_slot_replace_overlay.tree_exited.connect(_on_shop_slot_overlay_exited)
	_slot_replace_overlay.configure(
		run_state.run_deck.get_soulbound_slot_cards(),
		"Choose a Soulbound Slot to Replace",
		"Replace",
		"Back"
	)


func _on_shop_slot_selected(slot_card: CardData) -> void:
	if slot_card == null or _pending_shop_card == null or run_state == null or run_state.run_deck == null:
		return
	_pending_shop_slot_index = _find_soulbound_slot_index(slot_card)
	if _pending_shop_slot_index < 0:
		return
	_confirm_dialog.open(
		"Buy %s and replace %s for this run?" % [_pending_shop_card.name, slot_card.name],
		"Buy & Replace",
		"Cancel"
	)


func _on_shop_slot_selection_canceled() -> void:
	_clear_pending_shop_purchase()
	_slot_replace_overlay = null


func _on_shop_slot_overlay_exited() -> void:
	if is_instance_valid(_slot_replace_overlay):
		return
	_slot_replace_overlay = null


func _confirm_shop_soulbound_purchase() -> void:
	if run_state == null or run_state.run_deck == null or _pending_shop_card == null or _pending_shop_slot_index < 0:
		return
	if !run_state.run_deck.replace_soulbound_slot(_pending_shop_slot_index, _pending_shop_card):
		_clear_pending_shop_purchase()
		return
	run_state.gold -= _pending_shop_gold_cost
	if !run_state.pending_shop_claimed_card_offer_indices.has(_pending_shop_offer_index):
		run_state.pending_shop_claimed_card_offer_indices.append(_pending_shop_offer_index)
	_update_items()
	_clear_pending_shop_purchase()
	if run != null:
		run._persist_active_run()


func _clear_pending_shop_purchase() -> void:
	_pending_shop_card = null
	_pending_shop_slot_index = -1
	_pending_shop_gold_cost = 0
	_pending_shop_offer_index = -1


func _find_soulbound_slot_index(slot_card: CardData) -> int:
	if slot_card == null or run_state == null or run_state.run_deck == null:
		return -1
	slot_card.ensure_uid()
	var slot_cards := run_state.run_deck.get_soulbound_slot_cards()
	for slot_index in range(slot_cards.size()):
		var current := slot_cards[slot_index]
		if current == null:
			continue
		current.ensure_uid()
		if String(current.uid) == String(slot_card.uid):
			return slot_index
	return -1


func _is_card_offer_claimed(offer_index: int) -> bool:
	return run_state != null and run_state.pending_shop_claimed_card_offer_indices.has(offer_index)


func _is_arcanum_offer_claimed(offer_index: int) -> bool:
	return run_state != null and run_state.pending_shop_claimed_arcanum_offer_indices.has(offer_index)


func _get_modal_parent() -> Node:
	return ui_layer if ui_layer != null else self
