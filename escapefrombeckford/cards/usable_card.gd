class_name UsableCard extends Node2D

signal reparent_requested(which_usable_card: UsableCard)
signal mouse_entered(usablecard: UsableCard)
signal mouse_exited(usablecard: UsableCard)

var player: Player : set = _set_player
var battle_scene: BattleScene
var hand: Hand
var actions: Array[CardAction]
var card_name_str: String = "Card Name"
var card_description_str: String = "Card Description"
var cost_red: int = 1
var cost_green: int = 1
var cost_blue: int = 1
var card_data: CardData : set = _set_card_data
var original_index := 0

@onready var state: Label = $State
@onready var card_visuals: CardVisuals = $CardVisuals

@onready var click_area_area2d: Area2D = $ClickArea
@onready var card_back_sprite2d: Sprite2D = $CardBack
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []


var tween: Tween
var playable := true : set = _set_playable
var disabled := false
var selected = false

#@onready var space_state = get_world_2d().direct_space_state
#
#func _process(_delta):
	#var q = PhysicsPointQueryParameters2D.new()
	#q.position = get_global_mouse_position()
	#q.collide_with_areas = true
	#q.collision_mask = 1 << 5
	#var hits = space_state.intersect_point(q)
	#print("hits:", hits.size())


func _ready() -> void:
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_aim_ended.connect(_on_card_drag_or_aiming_ended)
	Events.card_drag_ended.connect(_on_card_drag_or_aiming_ended)
	Events.n_combatants_changed.connect(_on_n_combatants_changed)
	Events.player_combatant_data_changed.connect(_on_player_combatant_data_changed)
	card_state_machine.init(self)

func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)

func animate_to_position(new_position: Vector2, new_rotation: float, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.set_parallel()
	tween.tween_property(self, "global_position", new_position,  duration)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)

func animate_to_rotation(new_rotation: float, duration: float) -> void:
	tween = create_tween().set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees", new_rotation,  duration)

func _set_player(new_player: Player) -> void:
	player = new_player
	if !is_node_ready():
		await ready
	card_state_machine.player = player
	

func _set_card_data(_card_data: CardData) -> void:
	if !is_node_ready():
		await ready
	card_data = _card_data
	card_visuals.card_data = card_data
	for action_script : GDScript in card_data.actions:
		var new_action = CardAction.new()
		new_action.set_script(action_script)
		new_action.card_data = card_data
		new_action.player = player
		new_action.battle_scene = battle_scene
		actions.push_back(new_action)
	_update_graphics()
	playable = is_playable()

func highlight():
	if disabled == false and card_state_machine.current_state is BaseState:
		card_visuals.glow.show()

func unhighlight():
	card_visuals.glow.hide()

func set_usable_card_z_index(index: int):
	card_visuals.z_index = index
	#card_visuals.glow.z_index = index
	#card_visuals.card_front.z_index = index
	#card_visuals.name_label.z_index = index
	#card_visuals.description.z_index = index
	#card_visuals.card_art_rect.z_index = index
	#card_visuals.card_art_rect.z_index = index
	#card_visuals.cost_container.z_index = index
	#card_visuals.cost_red_sprites.z_index = index
	#card_visuals.cost_green_sprites.z_index = index
	#card_visuals.cost_blue_sprites.z_index = index
	#card_visuals.card_name_box.z_index = index

func get_cost() -> Array[int]:
	return [card_data.cost_red, card_data.cost_green, card_data.cost_blue]

func activate() -> bool:
	var action_processed: bool = false
	for action : CardAction in actions:
		action_processed = action.activate(targets)
	if action_processed: 
		Events.card_played.emit(self)
		if card_data.deplete or card_data.card_type == CardData.CardType.POWER:
			hand.deplete_card(hand.remove_card_by_entity(self))
		elif card_data.card_type == CardData.CardType.SUMMON:
			hand.reserve_summon_card(hand.remove_card_by_entity(self))
		else:
			hand.discard_card(hand.remove_card_by_entity(self))
	return action_processed

func _update_graphics():
	if card_visuals.name_label.get_text() != card_data.name:
		card_visuals.name_label.set_text(card_data.name)
	if card_visuals.description.get_text() != card_data.description:
		card_visuals.description.set_text(card_data.description)

func _on_click_area_mouse_entered() -> void:
	print("collision area: %s, collision mask: %s" % [click_area_area2d.collision_layer, click_area_area2d.collision_mask])
	print("monitoring: %s, monitorable: %s" % [click_area_area2d.monitoring, click_area_area2d.monitorable])
	card_state_machine.on_mouse_entered()
	mouse_entered.emit(self)

func _on_click_area_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()
	mouse_exited.emit(self)

func _on_drop_point_detector_area_entered(area: Area2D) -> void:
	if !targets.has(area):
		targets.push_back(area)

func _on_drop_point_detector_area_exited(area: Area2D) -> void:
	targets.erase(area)

func _on_card_drag_or_aiming_started(used_card: UsableCard) -> void:
	if used_card == self:
		return
	
	disabled = true

func _set_playable(value: bool) -> void:
	playable = value
	if not playable:
		card_visuals.cost_container.set_modulate(Color(1, 0.5, 0.1, 1))
	else:
		card_visuals.cost_container.set_modulate(Color(1, 1, 1, 1))

func is_playable() -> bool:
	var currently_playable: bool = true
	for card_action: CardAction in actions:
		if !card_action.is_playable():
			currently_playable = false
	return currently_playable

func _on_card_drag_or_aiming_ended(_usable_card: UsableCard) -> void:
	disabled = false
	playable = is_playable()

func _on_n_combatants_changed() -> void:
	playable = is_playable()

func _on_player_combatant_data_changed() -> void:
	playable = is_playable()
