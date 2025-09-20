class_name UsableCard extends Node2D

signal reparent_requested(which_usable_card: UsableCard)
signal mouse_entered(usablecard: UsableCard)
signal mouse_exited(usablecard: UsableCard)

var player: Player
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
#@onready var cost_blue_label: Label = $CostDisplay/CostBlue
#@onready var cost_red_label: Label = $CostDisplay/CostRed
#@onready var cost_green_label: Label = $CostDisplay/CostGreen
#@onready var cost_container: Sprite2D = $CostDisplay/CostContainer
#@onready var card_name_lbl: Label = $CardName/Name
#@onready var card_description_lbl: Label = $CardDescription/Description
#@onready var card_front_sprite2d: Sprite2D = $CardFront
@onready var card_back_sprite2d: Sprite2D = $CardBack
#@onready var card_art: Sprite2D = $CardArt
#@onready var card_art_rect: TextureRect = $CardArtRect
#@onready var card_glow: Sprite2D = $Glow
@onready var drop_point_detector: Area2D = $DropPointDetector
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []


#var parent: Node2D
var tween: Tween
var playable := true : set = _set_playable
var disabled := false
var selected = false

func _ready() -> void:
	Events.card_aim_started.connect(_on_card_drag_or_aiming_started)
	Events.card_drag_started.connect(_on_card_drag_or_aiming_started)
	Events.card_aim_ended.connect(_on_card_drag_or_aiming_ended)
	Events.card_drag_ended.connect(_on_card_drag_or_aiming_ended)
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

func _set_card_data(_card_data: CardData) -> void:
	if !is_node_ready():
		await ready
	card_data = _card_data
	card_visuals.card_data = card_data
	#card_art_rect.set_texture(card_data.texture)
	for action_script : GDScript in card_data.actions:
		var new_action = CardAction.new()
		new_action.set_script(action_script)
		#print(card_action.resource_name)
		#var new_action : CardAction = card_action.duplicate()
		new_action.card_data = card_data
		new_action.battle_scene = battle_scene
		actions.push_back(new_action)
	_update_graphics()

func _set_playable(value: bool) -> void:
	playable = value
	if not playable:
		card_visuals.cost_container.set_modulate(Color(1, 0.5, 0.1, 1))
		#cost.add_theme_color_override("font_color", Color.RED)
		#icon.modulate = Color(1, 1, 1, 0.5)
	else:
		card_visuals.cost_container.set_modulate(Color(1, 1, 1, 1))
		#cost.remove_theme_color_override("font_color")
		#icon.modulate = Color(1, 1, 1, 1)
#func load_card_data(cardwithid: CardWithID):
	#set_card_values(cardwithid.card.cost_red, cardwithid.card.cost_green, cardwithid.card.cost_blue, cardwithid.card.name, cardwithid.card.description, cardwithid)
	#card_art.set_texture(cardwithid.card.texture)
	#for script in cardwithid.card.actions:
		#var action_script = RefCounted.new()
		#action_script.set_script(script)
		#actions.push_back(action_script)

func highlight():
	if disabled == false and card_state_machine.current_state is BaseState:
		card_visuals.glow.show()

func unhighlight():
	card_visuals.glow.hide()

func set_usable_card_z_index(index: int):
	card_visuals.glow.z_index = index
	card_visuals.card_front.z_index = index
	card_visuals.name_label.z_index = index
	card_visuals.description.z_index = index
	card_visuals.card_art_rect.z_index = index
	card_visuals.card_art_rect.z_index = index
	card_visuals.cost_container.z_index = index
	card_visuals.cost_red_sprites.z_index = index
	card_visuals.cost_green_sprites.z_index = index
	card_visuals.cost_blue_sprites.z_index = index
	#state.z_index = index
	#card_back_sprite2d.z_index = index

func get_cost() -> Array[int]:
	return [card_data.cost_red, card_data.cost_green, card_data.cost_blue]

func activate() -> bool:
	var action_processed: bool = false
	for action : CardAction in actions:
		action_processed = action.activate(targets, player)
	if action_processed:
		Events.card_played.emit(self)
		if card_data.card_type != CardData.CardType.SUMMON:
			hand.discard_card(hand.remove_card_by_entity(self))
		else:
			hand.reserve_summon_card(hand.remove_card_by_entity(self))
	return action_processed

func _update_graphics():
	#if card_visuals.cost_blue.get_text() != str(card_data.cost_blue):
		#card_visuals.cost_blue.set_text(str(card_data.cost_blue))
	#if card_visuals.cost_red.get_text() != str(card_data.cost_red):
		#card_visuals.cost_red.set_text(str(card_data.cost_red))
	#if card_visuals.cost_green.get_text() != str(card_data.cost_green):
		#card_visuals.cost_green.set_text(str(card_data.cost_green))
	if card_visuals.name_label.get_text() != card_data.name:
		card_visuals.name_label.set_text(card_data.name)
	if card_visuals.description.get_text() != card_data.description:
		card_visuals.description.set_text(card_data.description)

func _on_player_combatant_data_changed() -> void:
	playable = player.can_play_card(card_data)

func _on_click_area_mouse_entered() -> void:
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

func _on_card_drag_or_aiming_ended(_usable_card: UsableCard) -> void:
	disabled = false
	playable = player.can_play_card(card_data)
