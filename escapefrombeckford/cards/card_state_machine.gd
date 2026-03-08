# card_state_machine.gd
class_name CardStateMachine extends Node

@export var initial_state: CardState

var current_state: CardState
var states := {}

var player_data: PlayerData : set = _set_player

func init(card: UsableCard) -> void:
	for child in get_children():
		if child is CardState:
			states[child.state] = child
			child.transition_requested.connect(_on_transition_requested)
			child.usable_card = card
	
	if initial_state:
		initial_state.enter()
		current_state = initial_state

func _set_player(new_player: PlayerData) -> void:
	player_data = new_player
	for child in get_children():
		if child is CardState:
			child.player_data = player_data

func on_input(event: InputEvent) -> void:
	if current_state:
		current_state.on_input(event)

#func on_gui_input(event: InputEvent) -> void:
	#if current_state:
		#current_state.on_gui_input(event)

func on_mouse_entered() -> void:
	if current_state:
		current_state.on_mouse_entered()

func on_mouse_exited() -> void:
	if current_state:
		current_state.on_mouse_exited()

func _on_transition_requested(from: CardState, to: CardState.State) -> void:
	if from != current_state:
		return
	
	var new_state: CardState = states[to]
	if not new_state:
		return
	
	if current_state:
		current_state.exit()
	
	new_state.enter()
	current_state = new_state
	current_state.dwell()

func request_state(to: CardState.State) -> void:
	_force_transition(to)

func _force_transition(to: CardState.State) -> void:
	var new_state: CardState = states.get(to)
	if new_state == null:
		return

	if current_state:
		current_state.exit()

	new_state.enter()
	current_state = new_state
	current_state.dwell()
