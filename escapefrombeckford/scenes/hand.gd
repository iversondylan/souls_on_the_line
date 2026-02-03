# hand.gd

class_name Hand extends Node2D

signal card_activated(card: UsableCard)
signal done_drawing()

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
const Z_BASE := 0
const Z_TOP := 10

var _top_locked_card: UsableCard = null # drag/aim wins
var _top_hover_card: UsableCard = null # hover wins if no lock
var _hand_globally_disabled := false

var battle_scene: BattleScene
var player: Player
var deck: Deck

var highlighted_card_index_int: int = -1
var currently_selected_card_index: int = -1
var mouse_in_hand_area: bool = false
var selected_card: UsableCard

#var _active_tween: Tween = null
var _is_drawing: bool = false
var _is_discarding: bool = false


func _ready() -> void:
	Events.request_draw_hand.connect(_on_request_draw_hand)
	
	Events.card_drag_ended.connect(_card_drag_or_aim_ended)
	Events.card_drag_started.connect(_on_card_drag_or_aim_started)
	
	Events.card_aim_started.connect(_on_card_drag_or_aim_started)
	Events.card_aim_ended.connect(_card_drag_or_aim_ended)
	
	Events.battlefield_aim_started.connect(_on_card_drag_or_aim_started)
	Events.battlefield_aim_ended.connect(_card_drag_or_aim_ended)
	
	Events.player_turn_completed.connect(_on_player_turn_completed)


func _process(_delta: float) -> void:
	if _is_discarding:
		return

	# Always keep z order correct
	_apply_z_order()

	# If a card is being dragged/aimed, suppress hover visuals entirely
	if is_instance_valid(_top_locked_card):
		_clear_hover_visuals()
		_top_hover_card = null
		return

	# Normal hover logic
	var hovered_cards: Array[UsableCard] = []
	for card in _get_hand_cards():
		if card.is_mouse_over():
			hovered_cards.append(card)

	var top_card: UsableCard = null
	if hovered_cards.size() > 0:
		top_card = _pick_top_by_tree_order(hovered_cards)

	_top_hover_card = top_card
	_apply_z_order()
	_apply_hover_visuals(top_card)

func _get_hand_cards() -> Array[UsableCard]:
	var out: Array[UsableCard] = []
	for child in hand_cards_node.get_children():
		if child is UsableCard and is_instance_valid(child):
			out.append(child)
	return out

func get_hand_cards() -> Array[UsableCard]:
	# public alias (kept name for compatibility)
	return _get_hand_cards()

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
	reposition_hand_cards()

func draw_card() -> bool:
	var c := deck.draw_card()
	if c == null:
		return false
	add_card(c)
	return true

func draw_cards(n_cards: int) -> void:
	_is_drawing = true
	for i in range(n_cards):
		draw_card()
		await get_tree().create_timer(CARD_DRAW_INTERVAL).timeout
	_is_drawing = false
	done_drawing.emit()

func draw_hand(n_cards: int) -> void:
	draw_cards(n_cards)
	Events.hand_drawn.emit()

func _draw_first_hand_with_summon_guarantee(n_cards: int) -> void:
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
		add_card(c)
		await get_tree().create_timer(CARD_DRAW_INTERVAL).timeout
	_is_drawing = false
	Events.hand_drawn.emit()

func reserve_summon_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	usable_card.queue_free()
	# no discard addition for reserve
	reposition_hand_cards()

func discard_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	deck.add_card_to_discard(usable_card.card_data)
	usable_card.queue_free()
	reposition_hand_cards()

func deplete_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	usable_card.queue_free()
	reposition_hand_cards()

func discard_hand(usable_cards: Array[UsableCard]) -> void:
	# If already discarding, don't start another batch.
	# (Optional recovery: if somehow stuck, auto-unstick when disabled node is empty)
	if _is_discarding:
		if _count_cards_in(disabled_cards_node) == 0:
			_is_discarding = false
		else:
			return

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

	var target_global := discard_anchor.global_position

	for i in range(cards.size() - 1, -1, -1):
		var card: UsableCard = cards[i]
		if !is_instance_valid(card):
			continue

		# Freeze it
		card.disabled = true
		card.unhighlight()
		card.selected = false

		# Reparent but preserve global position
		var g := card.global_position
		if card.get_parent():
			card.get_parent().remove_child(card)
		disabled_cards_node.add_child(card)
		reposition_hand_cards()
		card.global_position = g
		card.z_index = Z_TOP
		var card_ref := card
		card_ref.animate_to_position(
			target_global,
			0.0,
			0.5,
			MINI_CARD_SCALE,
			func():
				# Important: remove from tree regardless, then free.
				if is_instance_valid(card_ref):
					deck.add_card_to_discard(card_ref.card_data)
					var parent := card_ref.get_parent()
					if parent:
						parent.remove_child(card_ref)
					card_ref.queue_free()

				# Defer the completion check so queued frees / tree updates settle.
				call_deferred("_on_one_discard_complete")
		)
		reposition_hand_cards()
		await get_tree().create_timer(CARD_DISCARD_INTERVAL).timeout


func _count_cards_in(node: Node) -> int:
	var n := 0
	for ch in node.get_children():
		if ch is UsableCard and is_instance_valid(ch):
			n += 1
	return n

func _on_one_discard_complete() -> void:
	var remaining := _count_cards_in(disabled_cards_node)
	#print("discard remaining:", remaining)

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

func get_card_position(angle_deg_flt: float) -> Vector2:
	var x: float = hand_radius_flt * cos(deg_to_rad(angle_deg_flt + 270))
	var y: float = hand_radius_flt * sin(deg_to_rad(angle_deg_flt + 270))
	return collision_shape.position + Vector2(x, y)

func _update_card_transform(usable_card: UsableCard, angle_in_drag: float) -> void:
	var pos: Vector2 = get_card_position(angle_in_drag)
	usable_card.animate_to_position(pos, angle_in_drag, 0.5)

func _on_usable_card_reparent_requested(_child: UsableCard) -> void:
	reposition_hand_cards()

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

func _on_card_drag_or_aim_started(card: UsableCard) -> void:
	_top_locked_card = card
	_top_hover_card = null
	_clear_hover_visuals()
	_apply_z_order()


func _card_drag_or_aim_ended(card: UsableCard) -> void:
	if _top_locked_card == card:
		_top_locked_card = null
	_clear_hover_visuals()
	_apply_z_order()

func _on_player_turn_completed() -> void:
	#print("hand.gd _on_player_turn_completed()")
	disable_hand_cards()
	discard_hand(get_hand_cards())

func _pick_top_by_tree_order(cards: Array[UsableCard]) -> UsableCard:
	var best: UsableCard = null
	var best_idx := -999999
	for c in cards:
		if !is_instance_valid(c):
			continue
		# child order within its parent: higher index draws later (on top) when z_index ties
		var idx := c.get_index()
		if idx > best_idx:
			best_idx = idx
			best = c
	return best

func _apply_hover_visuals(top_card: UsableCard) -> void:
	# reset selection visuals
	for card in _get_hand_cards():
		card.unhighlight()
		card.selected = false
		card.reset_visuals()

	if is_instance_valid(top_card):
		top_card.highlight()
		top_card.selected = true
		top_card.enlarge_visuals()
		currently_selected_card_index = _get_hand_cards().find(top_card)
	else:
		currently_selected_card_index = -1

func _apply_z_order() -> void:
	var cards := _get_hand_cards()

	# Baseline: let child order decide (all z = 0)
	for c in cards:
		if is_instance_valid(c):
			c.z_index = Z_BASE

	# Decide who should be on top
	var top: UsableCard = null
	if is_instance_valid(_top_locked_card):
		top = _top_locked_card
	elif is_instance_valid(_top_hover_card):
		top = _top_hover_card

	if is_instance_valid(top):
		top.z_index = Z_TOP

func _clear_hover_visuals() -> void:
	for card in _get_hand_cards():
		card.unhighlight()
		card.selected = false
		card.reset_visuals()
	currently_selected_card_index = -1
