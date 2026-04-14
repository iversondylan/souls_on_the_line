# hand.gd

class_name Hand extends Control

signal card_activated(card: UsableCard)
signal done_drawing()
signal discard_animation_completed()

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
@onready var usable_card_scn: PackedScene = preload("uid://cd6j7t8hq3we3")

const CARD_DRAW_INTERVAL: float = 0.1
const CARD_DISCARD_INTERVAL: float = 0.1
const MINI_CARD_SCALE := Vector2(0.2, 0.2)
const Z_BASE := 0
const Z_TOP := 10

var _top_locked_card: UsableCard = null # drag/aim wins
var _top_hover_card: UsableCard = null # hover wins if no lock
var _hand_globally_disabled := false

#var battle_scene: BattleScene
var battle_view: BattleView
var sim_host: SimHost

var api: SimBattleAPI

#var player_data: PlayerData
var bins: BattleCardBins

var highlighted_card_index_int: int = -1
var currently_selected_card_index: int = -1
var mouse_in_hand_area: bool = false
var selected_card: UsableCard

#var _active_tween: Tween = null
var _is_drawing: bool = false
var _is_discarding: bool = false
var _emit_discard_animation_finished_on_complete := false
var _modal_selecting : bool = false


func _ready() -> void:
	Events.card_drag_ended.connect(_card_drag_or_aim_ended)
	Events.card_drag_started.connect(_on_card_drag_or_aim_started)
	
	Events.card_aim_started.connect(_on_card_drag_or_aim_started)
	Events.card_aim_ended.connect(_card_drag_or_aim_ended)
	
	Events.battlefield_aim_started.connect(_on_card_drag_or_aim_started)
	Events.battlefield_aim_ended.connect(_card_drag_or_aim_ended)


func _process(_delta: float) -> void:
	if _is_discarding:
		return
	if _modal_selecting:
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

func refresh_hand_cards() -> void:
	for usable_card in _get_hand_cards():
		if usable_card == null or !is_instance_valid(usable_card):
			continue
		usable_card.refresh_from_card_data()
		apply_disabled_state_to_card(usable_card)

func add_card(card: CardData) -> void:
	if card == null:
		push_error("Hand.add_card(): tried to add null CardData")
		return

	var usable_card: UsableCard = usable_card_scn.instantiate()
	usable_card.card_data = card
	usable_card.hand = self
	#usable_card.player_data = player_data
	usable_card.battle_view = battle_view
	usable_card.sim_host = sim_host
	
	usable_card.api = api
	
	hand_cards_node.add_child(usable_card)
	var target_global := draw_anchor.global_position
	usable_card.global_position = target_global
	usable_card.scale = MINI_CARD_SCALE
	usable_card.card_fan_requested.connect(_on_usable_card_card_fan_requested)
	apply_disabled_state_to_card(usable_card)
	reposition_hand_cards()
	Events.hand_card_added.emit(usable_card)

func present_draw_cards(cards: Array[CardData]) -> void:
	_is_drawing = true
	for card in cards:
		if card == null:
			continue
		add_card(card)
		await get_tree().create_timer(CARD_DRAW_INTERVAL).timeout
	_is_drawing = false
	done_drawing.emit()

func draw_cards_from_ctx(ctx: DrawContext) -> void:
	await present_draw_cards(ctx.drawn_cards)

func discard_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	if bins != null and usable_card.card_data != null:
		bins.discard_card_from_hand(usable_card.card_data)
	usable_card.queue_free()
	reposition_hand_cards()

func deplete_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return
	if bins != null and usable_card.card_data != null:
		bins.exhaust_card_from_hand(usable_card.card_data)
	usable_card.queue_free()
	reposition_hand_cards()

func set_modal_selecting(on: bool) -> void:
	_modal_selecting = on
	# also clear hover/top state so nothing is "stuck on top"
	_top_locked_card = null
	_top_hover_card = null
	_clear_hover_visuals()

func discard_cards(usable_cards: Array[UsableCard]) -> void:
	_discard_cards_internal(usable_cards, true)


func discard_hand(usable_cards: Array[UsableCard]) -> void:
	_discard_cards_internal(usable_cards, true)


func animate_discard_cards(usable_cards: Array[UsableCard], emit_discard_animation_finished: bool = true) -> void:
	_discard_cards_internal(usable_cards, emit_discard_animation_finished)
	if _is_discarding:
		await discard_animation_completed


func _discard_cards_internal(usable_cards: Array[UsableCard], emit_discard_animation_finished: bool) -> void:
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

	# Nothing to do
	if cards.is_empty():
		discard_animation_completed.emit()
		return

	# No anchor => instant discard
	if discard_anchor == null:
		push_warning("Hand._discard_cards_internal(): discard_anchor not set; falling back to instant discard")
		for c in cards:
			c.queue_free()
		reposition_hand_cards()
		discard_animation_completed.emit()
		return

	_is_discarding = true
	_emit_discard_animation_finished_on_complete = emit_discard_animation_finished

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
					var parent := card_ref.get_parent()
					if parent:
						parent.remove_child(card_ref)
					card_ref.queue_free()

				# Defer the completion check so queued frees / tree updates settle.
				call_deferred("_on_one_discard_complete")
		)

		reposition_hand_cards()
		await get_tree().create_timer(CARD_DISCARD_INTERVAL).timeout


func _on_one_discard_complete() -> void:
	var remaining := _count_cards_in(disabled_cards_node)
	if remaining != 0:
		return

	_is_discarding = false
	reposition_hand_cards()
	_emit_discard_animation_finished_on_complete = false
	discard_animation_completed.emit()


func _count_cards_in(node: Node) -> int:
	var n := 0
	for ch in node.get_children():
		if ch is UsableCard and is_instance_valid(ch):
			n += 1
	return n





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

	# Normal path: card is a child of hand_cards_node
	var cards := _get_hand_cards()
	var idx := cards.find(card)
	if idx >= 0:
		return remove_card(idx)

	# Fallback: card might be reparented during drag/aim/state transitions.
	# Remove it from its current parent anyway, so destination functions can queue_free it.
	if card.get_parent() != null:
		push_warning("Hand.remove_card_by_entity(): card not found in hand_cards_node; removing from current parent instead")
		card.get_parent().remove_child(card)
		reposition_hand_cards()
		currently_selected_card_index = -1
		return card

	push_error("Hand.remove_card_by_entity(): card has no parent; cannot remove")
	return null


#func remove_card_by_entity(card: UsableCard) -> UsableCard:
	#if card == null or !is_instance_valid(card):
		#push_error("Hand.remove_card_by_entity(): invalid card")
		#return null
	#var cards := _get_hand_cards()
	#var idx := cards.find(card)
	#if idx < 0:
		#push_error("Hand.remove_card_by_entity(): card not found")
		#return null
	#return remove_card(idx)

func remove_cards_by_entities(usable_cards: Array[UsableCard]) -> Array[UsableCard]:
	var removing_cards: Array[UsableCard] = []
	for usable_card in usable_cards:
		var removed := remove_card_by_entity(usable_card)
		if removed != null:
			removing_cards.append(removed)
	return removing_cards


func get_hand_cards_by_uids(card_uids: Array[String]) -> Array[UsableCard]:
	var wanted := {}
	for uid in card_uids:
		wanted[String(uid)] = true

	var out: Array[UsableCard] = []
	for card in _get_hand_cards():
		if card == null or !is_instance_valid(card) or card.card_data == null:
			continue
		card.card_data.ensure_uid()
		if wanted.has(String(card.card_data.uid)):
			out.append(card)
	return out


func remove_cards_by_uids(card_uids: Array[String]) -> Array[UsableCard]:
	return remove_cards_by_entities(get_hand_cards_by_uids(card_uids))


func clear_removed_cards(usable_cards: Array[UsableCard]) -> void:
	for usable_card in usable_cards:
		if usable_card == null or !is_instance_valid(usable_card):
			continue
		usable_card.queue_free()
	reposition_hand_cards()

func empty_hand() -> void:
	currently_selected_card_index = -1
	for card in _get_hand_cards():
		card.queue_free()

func disable_hand_cards() -> void:
	_hand_globally_disabled = true
	for usable_card in _get_hand_cards():
		usable_card.unhighlight()
		apply_disabled_state_to_card(usable_card)

func lock_cards_for_selection() -> void:
	for usable_card in _get_hand_cards():
		usable_card.unhighlight()

func enable_hand_cards() -> void:
	_hand_globally_disabled = false
	for usable_card in _get_hand_cards():
		apply_disabled_state_to_card(usable_card)


func refresh_locked_card_states() -> void:
	for usable_card in _get_hand_cards():
		apply_disabled_state_to_card(usable_card)


func apply_disabled_state_to_card(usable_card: UsableCard) -> void:
	if usable_card == null or !is_instance_valid(usable_card):
		return

	var should_disable := _hand_globally_disabled
	if !should_disable and bins != null and usable_card.card_data != null:
		usable_card.card_data.ensure_uid()
		should_disable = bins.is_hand_card_locked_until_next_player_turn(String(usable_card.card_data.uid))

	usable_card.disabled = should_disable
	usable_card.playable = usable_card.is_playable()

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
	return position + collision_shape.position + Vector2(x, y)

func _update_card_transform(usable_card: UsableCard, angle_in_drag: float) -> void:
	var pos: Vector2 = get_card_position(angle_in_drag)
	usable_card.animate_to_position(pos, angle_in_drag, 0.5)

func _on_usable_card_card_fan_requested(_child: UsableCard) -> void:
	reposition_hand_cards()

func _on_hand_area_mouse_entered() -> void:
	mouse_in_hand_area = true

func _on_hand_area_mouse_exited() -> void:
	mouse_in_hand_area = false

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
