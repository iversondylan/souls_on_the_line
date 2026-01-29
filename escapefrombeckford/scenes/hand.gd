# hand.gd

class_name Hand extends Node2D

signal card_activated(card: UsableCard)

@export var discard_anchor_path: NodePath
@export var draw_anchor_path: NodePath
@onready var discard_anchor: Control = get_node_or_null(discard_anchor_path)
@onready var draw_anchor: Control = get_node_or_null(draw_anchor_path)

@export var card_angle: float = 0
@export var card_angle_limit_flt: float = 35
@export var max_card_spread_angle_flt: float = 5

@onready var hand_cards_node: Node2D = $HandCardsNode
@onready var disabled_cards_node: Node2D = $DisabledCardsNode

@onready var collision_shape: CollisionShape2D = $DebugShape
@onready var hand_radius_flt: float = collision_shape.shape.radius
@onready var usable_card_scn: PackedScene = preload("res://cards/usable_card.tscn")

const CARD_DRAW_INTERVAL: float = 0.1
const CARD_DISCARD_INTERVAL: float = 0.1
const MINI_CARD_SCALE := Vector2(0.2, 0.2)

var battle_scene: BattleScene
var player: Player
var deck: Deck

var highlighted_card_index_int: int = -1
var currently_touched_cards_arr: Array[UsableCard] = [] # leaving as-is; you can remove later if unused
var currently_selected_card_index: int = -1
var mouse_in_hand_area: bool = false
var selected_card: UsableCard

#var _active_tween: Tween = null
var _is_drawing: bool = false
var _is_discarding: bool = false


func _ready() -> void:
	Events.card_played.connect(_on_card_played)
	Events.request_draw_hand.connect(_on_request_draw_hand)

	Events.card_drag_started.connect(_on_card_drag_or_aim_started)
	Events.card_aim_started.connect(_on_card_drag_or_aim_started)
	Events.battlefield_aim_started.connect(_on_card_drag_or_aim_started)

	Events.card_drag_ended.connect(_card_drag_or_aim_ended)
	Events.card_aim_ended.connect(_card_drag_or_aim_ended)

	Events.player_turn_completed.connect(_on_player_turn_completed)


func _process(_delta: float) -> void:
	var hovered_cards: Array[UsableCard] = []

	for card in _get_hand_cards():
		if card.is_mouse_over():
			hovered_cards.append(card)

	# reset selection visuals
	for card in _get_hand_cards():
		card.unhighlight()
		card.selected = false

	if hovered_cards.size() > 0:
		hovered_cards.sort_custom(func(a, b): return a.z_index < b.z_index)
		var top_card: UsableCard = hovered_cards.back()
		top_card.highlight()
		top_card.selected = true
		currently_selected_card_index = _get_hand_cards().find(top_card)
	else:
		currently_selected_card_index = -1


# ------------------------------------------------------------------------------
# Core hand list access (no hand_cards_arr)
# ------------------------------------------------------------------------------

func _get_hand_cards() -> Array[UsableCard]:
	var out: Array[UsableCard] = []
	for child in hand_cards_node.get_children():
		if child is UsableCard and is_instance_valid(child):
			out.append(child)
	return out

func get_hand_cards() -> Array[UsableCard]:
	# public alias (kept name for compatibility)
	return _get_hand_cards()


# ------------------------------------------------------------------------------
# Adding / drawing
# ------------------------------------------------------------------------------

func add_card(card: CardData) -> void:
	if card == null:
		push_error("Hand.add_card(): tried to add null CardData")
		return

	var usable_card: UsableCard = usable_card_scn.instantiate()
	usable_card.card_data = card
	usable_card.hand = self
	usable_card.player = player
	usable_card.battle_scene = battle_scene
	
	hand_cards_node.add_child(usable_card)
	var target_global := draw_anchor.global_position
	usable_card.global_position = target_global
	usable_card.scale = MINI_CARD_SCALE
	usable_card.reparent_requested.connect(_on_usable_card_reparent_requested)

	#update_original_index()
	reposition_hand_cards()

func draw_card() -> bool:
	var c := deck.draw_card()
	if c == null:
		return false
	add_card(c)
	return true

func draw_hand(n_cards: int) -> void:
	#_cancel_active_tween()
	_is_drawing = true

	#var tween := create_tween()
	#_active_tween = tween

	for i in range(n_cards):
		#tween.tween_callback(func():
		draw_card()
		#)
		await get_tree().create_timer(CARD_DRAW_INTERVAL).timeout

		#tween.tween_interval(CARD_DRAW_INTERVAL)

	#tween.finished.connect(func():
	_is_drawing = false
	#_active_tween = null
	Events.hand_drawn.emit()
	#)

func _draw_first_hand_with_summon_guarantee(n_cards: int) -> void:
	#_cancel_active_tween()
	_is_drawing = true
	
	# Mark immediately so we can't re-enter and do it twice.
	deck.first_hand_drawn = true
	
	# Draw exactly like normal (uses deck.draw_card(), including reshuffles + size signals).
	var drawn: Array[CardData] = []
	for i in range(n_cards):
		var c := deck.draw_card()
		if c != null:
			drawn.append(c)
	
	# If we already have a summon, proceed normally.
	var has_summon := false
	for c in drawn:
		if c != null and c.card_type == CardData.CardType.SUMMON:
			has_summon = true
			break
	
	# If not, swap in a random summon from the REMAINING draw pile.
	if !has_summon and drawn.size() > 0:
		var summon_indices: Array[int] = []
		for idx in range(deck.draw_pile.cards.size()):
			var c: CardData = deck.draw_pile.cards[idx]
			if c != null and c.card_type == CardData.CardType.SUMMON:
				summon_indices.append(idx)
	
		if summon_indices.size() > 0:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
	
			var draw_pile_idx := summon_indices[rng.randi_range(0, summon_indices.size() - 1)]
			var hand_idx := rng.randi_range(0, drawn.size() - 1)
	
			var summon_card: CardData = deck.draw_pile.cards[draw_pile_idx]
			deck.draw_pile.cards[draw_pile_idx] = drawn[hand_idx]
			drawn[hand_idx] = summon_card
	
	for c in drawn:
		#tween.tween_callback(func():
		add_card(c)
		#)
		await get_tree().create_timer(CARD_DRAW_INTERVAL).timeout

		#tween.tween_interval(CARD_DRAW_INTERVAL)

	#tween.finished.connect(func():
	_is_drawing = false
	#_active_tween = null
	Events.hand_drawn.emit()
	#)
	# Animate the exact same way as draw_hand()
	#var tween := create_tween()
	#_active_tween = tween
	#
	#for c in drawn:
		#tween.tween_callback(add_card.bind(c))
		#tween.tween_interval(CARD_DRAW_INTERVAL)
	#
	#tween.finished.connect(func():
		#_is_drawing = false
		#_active_tween = null
		#Events.hand_drawn.emit()
	#)


# ------------------------------------------------------------------------------
# Removing / discarding
# ------------------------------------------------------------------------------

func reserve_summon_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	usable_card.queue_free()
	# no discard addition for reserve
	#update_original_index()
	reposition_hand_cards()

func discard_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	deck.add_card_to_discard(usable_card.card_data)
	usable_card.queue_free()
	#update_original_index()
	reposition_hand_cards()

func deplete_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	usable_card.queue_free()
	#update_original_index()
	reposition_hand_cards()

func discard_hand(usable_cards: Array[UsableCard]) -> void:
	# Filter to valid
	var cards: Array[UsableCard] = []
	for c in usable_cards:
		if c != null and is_instance_valid(c):
			cards.append(c)

	if cards.is_empty():
		Events.hand_discarded.emit()
		return

	if discard_anchor == null:
		push_warning("Hand.discard_hand(): discard_anchor not set; falling back to instant discard")
		for c in cards:
			deck.add_card_to_discard(c.card_data)
			c.queue_free()
		Events.hand_discarded.emit()
		return
	
	_is_discarding = true
	
	# Use global positions so parenting doesn't matter
	var target_global := discard_anchor.global_position
	
	#for c in cards:
	for i in range(cards.size() - 1, -1, -1):
		#var c: UsableCard = cards[i]
		var card : UsableCard = cards[i]
		# Optional: stop hand repositioning from yanking them mid-flight
		card.disabled = true
		card.unhighlight()
		card.selected = false
		var g := card.global_position
		hand_cards_node.remove_child(card)
		disabled_cards_node.add_child(card)
		card.global_position = g
		
		
		
		var card_for_lambda :  UsableCard = cards[i]
		card_for_lambda.animate_to_position(target_global, 0.0, 0.5, MINI_CARD_SCALE,
			func():
			var p: Node2D
			if is_instance_valid(card_for_lambda):
				p = card_for_lambda.get_parent()
				deck.add_card_to_discard(card_for_lambda.card_data)
			if p:
				p.remove_child(card_for_lambda)
			card_for_lambda.queue_free()
			_on_one_discard_complete()
			)
		await get_tree().create_timer(CARD_DISCARD_INTERVAL).timeout

func _count_cards_in(node: Node) -> int:
	var n := 0
	for ch in node.get_children():
		if ch is UsableCard and is_instance_valid(ch):
			n += 1
	return n

func _on_one_discard_complete() -> void:
	var remaining := _count_cards_in(hand_cards_node) + _count_cards_in(disabled_cards_node)
	print(remaining)
	if remaining != 0:
		return
	_is_discarding = false
	reposition_hand_cards()
	Events.hand_discarded.emit()


func remove_card(index: int) -> UsableCard:
	var cards := _get_hand_cards()
	if index < 0 or index >= cards.size():
		push_error("Hand.remove_card(): index out of range %s" % index)
		return null

	var removing: UsableCard = cards[index]
	# Detach from node tree so it disappears from the hand immediately.
	removing.get_parent().remove_child(removing)

	#update_original_index()
	reposition_hand_cards()
	currently_selected_card_index = -1
	return removing # caller must queue_free / reparent / etc.

func remove_card_by_entity(card: UsableCard) -> UsableCard:
	if card == null or !is_instance_valid(card):
		push_error("Hand.remove_card_by_entity(): invalid card")
		return null
	var cards := _get_hand_cards()
	var idx := cards.find(card)
	if idx < 0:
		push_error("Hand.remove_card_by_entity(): card not found")
		return null
	return remove_card(idx)

func remove_cards_by_entities(usable_cards: Array[UsableCard]) -> Array[UsableCard]:
	var removing_cards: Array[UsableCard] = []
	for usable_card in usable_cards:
		var removed := remove_card_by_entity(usable_card)
		if removed != null:
			removing_cards.append(removed)
	return removing_cards

func empty_hand() -> void:
	currently_selected_card_index = -1
	for card in _get_hand_cards():
		card.queue_free()
	currently_touched_cards_arr.clear()


# ------------------------------------------------------------------------------
# Enable/disable and visuals
# ------------------------------------------------------------------------------

func disable_hand_cards() -> void:
	for usable_card in _get_hand_cards():
		usable_card.unhighlight()
		usable_card.disabled = true

func enable_hand_cards() -> void:
	for usable_card in _get_hand_cards():
		usable_card.disabled = false

func reposition_hand_cards() -> void:
	var cards := _get_hand_cards()
	var card_spread_angle_flt: float = 0
	var current_card_angle_flt: float = 0
	var card_angle_increment_flt: float = 0

	if cards.size() >= 2:
		card_spread_angle_flt = min(card_angle_limit_flt, max_card_spread_angle_flt * (cards.size() - 1))
		current_card_angle_flt = -card_spread_angle_flt / 2
		card_angle_increment_flt = card_spread_angle_flt / (cards.size() - 1)

	for card in cards:
		_update_card_transform(card, current_card_angle_flt)
		current_card_angle_flt += card_angle_increment_flt

#func update_original_index() -> void:
	#var index := 0
	#for child in hand_cards_node.get_children():
		#if child is UsableCard and is_instance_valid(child):
			#(child as UsableCard).original_index = index
			#index += 1

func get_card_position(angle_deg_flt: float) -> Vector2:
	var x: float = hand_radius_flt * cos(deg_to_rad(angle_deg_flt + 270))
	var y: float = hand_radius_flt * sin(deg_to_rad(angle_deg_flt + 270))
	return collision_shape.position + Vector2(x, y)

func _update_card_transform(usable_card: UsableCard, angle_in_drag: float) -> void:
	var pos: Vector2 = get_card_position(angle_in_drag)
	usable_card.animate_to_position(pos, angle_in_drag, 0.5)

func _on_usable_card_reparent_requested(_child: UsableCard) -> void:
	#update_original_index()
	reposition_hand_cards()


# ------------------------------------------------------------------------------
# Tween + event handlers
# ------------------------------------------------------------------------------

#func _cancel_active_tween() -> void:
	#if _active_tween and is_instance_valid(_active_tween):
		#_active_tween.kill()
	#_active_tween = null
	#_is_drawing = false
	#_is_discarding = false

func _on_card_played(usable_card: UsableCard) -> void:
	currently_touched_cards_arr.erase(usable_card)

func _on_hand_area_mouse_entered() -> void:
	mouse_in_hand_area = true

func _on_hand_area_mouse_exited() -> void:
	mouse_in_hand_area = false

func _on_request_draw_hand() -> void:
	var n := 5
	if deck and !deck.first_hand_drawn and deck.first_hand_summon_guarantee:
		_draw_first_hand_with_summon_guarantee(n)
	else:
		draw_hand(n)

func _on_card_drag_or_aim_started(_usable_card: UsableCard) -> void:
	_usable_card.set_usable_card_z_index(2)

func _card_drag_or_aim_ended(_usable_card: UsableCard) -> void:
	_usable_card.set_usable_card_z_index(0)

func _on_player_turn_completed() -> void:
	disable_hand_cards()
	discard_hand(get_hand_cards())
