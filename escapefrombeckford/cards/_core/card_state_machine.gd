# card_state_machine.gd
class_name CardStateMachine extends Node

const DRAG_MINIMUM_THRESHOLD := 0.05
const MOUSE_Y_SNAPBACK_THRESHOLD := 1060

var current_state: int = -1
var usable_card: UsableCard
var player_data: PlayerData
var _minimum_drag_time_elapsed := false
var _drag_generation := 0
var _released_played := false

func init(card: UsableCard) -> void:
	usable_card = card
	request_state(CardState.State.BASE)

func is_in_state(state: CardState.State) -> bool:
	return int(current_state) == int(state)

func request_state(to: CardState.State) -> void:
	_transition(int(to))

func on_input(event: InputEvent) -> void:
	_handle_input_for(int(current_state), event)

func on_mouse_entered() -> void:
	_handle_mouse_entered_for(int(current_state))

func on_mouse_exited() -> void:
	_handle_mouse_exited_for(int(current_state))

func _transition(to: int) -> void:
	if usable_card == null:
		return
	if to < int(CardState.State.BASE) or to > int(CardState.State.SELECTED):
		return

	_exit_state(int(current_state))
	_enter_state(int(to))
	current_state = int(to)
	_dwell_state(int(to))

func _enter_state(state: int) -> void:
	match state:
		CardState.State.BASE:
			_enter_base()
		CardState.State.CLICKED:
			usable_card.drop_point_detector.monitoring = true
		CardState.State.DRAGGING:
			_enter_dragging()
		CardState.State.AIMING:
			_enter_aiming()
		CardState.State.RELEASED:
			_enter_released()
		CardState.State.SELECTION:
			_enter_selection()
		CardState.State.SELECTED:
			_enter_selected()

func _exit_state(state: int) -> void:
	match state:
		CardState.State.DRAGGING:
			Events.card_drag_ended.emit(usable_card)
		CardState.State.AIMING:
			if usable_card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
				Events.battlefield_aim_ended.emit(usable_card)
			else:
				Events.card_aim_ended.emit(usable_card)

func _dwell_state(state: int) -> void:
	if state == int(CardState.State.RELEASED):
		_transition(int(CardState.State.BASE))

func _handle_input_for(state: int, event: InputEvent) -> void:
	match state:
		CardState.State.BASE:
			_handle_base_input(event)
		CardState.State.CLICKED:
			if event is InputEventMouseMotion:
				_transition(int(CardState.State.DRAGGING))
		CardState.State.DRAGGING:
			_handle_dragging_input(event)
		CardState.State.AIMING:
			_handle_aiming_input(event)
		CardState.State.RELEASED:
			if !_released_played_on_enter():
				_transition(int(CardState.State.BASE))
		CardState.State.SELECTION:
			_handle_selection_input(event)
		CardState.State.SELECTED:
			_handle_selected_input(event)

func _handle_mouse_entered_for(_state: int) -> void:
	pass

func _handle_mouse_exited_for(_state: int) -> void:
	pass

func _enter_base() -> void:
	if usable_card == null:
		return
	if !usable_card.is_node_ready():
		await usable_card.ready
	usable_card.card_visuals.glow.hide()
	usable_card.card_fan_requested.emit(usable_card)

func _handle_base_input(event: InputEvent) -> void:
	if usable_card == null or !usable_card.playable or usable_card.disabled:
		return
	if event.is_action_pressed("mouse_click") and usable_card.selected:
		usable_card.global_position = usable_card.get_global_mouse_position()
		_transition(int(CardState.State.CLICKED))

func _enter_dragging() -> void:
	if usable_card == null:
		return
	usable_card.card_visuals.glow.hide()
	Events.card_drag_started.emit(usable_card)
	usable_card.animate_to_rotation(0, 0.2)
	_minimum_drag_time_elapsed = false
	_drag_generation += 1
	var generation := _drag_generation
	var threshold_timer := get_tree().create_timer(DRAG_MINIMUM_THRESHOLD, false)
	threshold_timer.timeout.connect(func():
		if generation == _drag_generation and is_in_state(CardState.State.DRAGGING):
			_minimum_drag_time_elapsed = true
	)

func _handle_dragging_input(event: InputEvent) -> void:
	if usable_card == null or usable_card.card_data == null:
		return
	var single_targeted := usable_card.card_data.is_single_targeted()
	var player_target := usable_card.card_data.target_type == CardData.TargetType.SELF
	var mouse_motion := event is InputEventMouseMotion
	var cancel := event.is_action_pressed("right_mouse")
	var confirm := event.is_action_released("mouse_click") or event.is_action_pressed("mouse_click")

	if single_targeted and mouse_motion and usable_card.targets.size() > 0:
		_transition(int(CardState.State.AIMING))
		return

	if player_target and mouse_motion and usable_card.targets.size() > 0:
		Events.player_targeted_arrow_visible.emit(true)

	if player_target and mouse_motion and usable_card.targets.size() == 0:
		Events.player_targeted_arrow_visible.emit(false)

	if mouse_motion:
		usable_card.global_position = usable_card.get_global_mouse_position()

	if cancel:
		Events.player_targeted_arrow_visible.emit(false)
		_transition(int(CardState.State.BASE))
	elif _minimum_drag_time_elapsed and confirm:
		Events.player_targeted_arrow_visible.emit(false)
		get_viewport().set_input_as_handled()
		_transition(int(CardState.State.RELEASED))

func _enter_aiming() -> void:
	if usable_card == null or usable_card.card_data == null:
		return
	usable_card.targets.clear()
	var pos := get_viewport().get_visible_rect().size
	pos.x = pos.x * 0.5
	pos.y = pos.y * 0.75
	usable_card.animate_to_position(pos, 0, 0.2)
	usable_card.drop_point_detector.monitoring = false
	if usable_card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
		Events.battlefield_aim_started.emit(usable_card)
	else:
		Events.card_aim_started.emit(usable_card)

func _handle_aiming_input(event: InputEvent) -> void:
	if usable_card == null:
		return
	var mouse_motion := event is InputEventMouseMotion
	var mouse_at_bottom := usable_card.get_global_mouse_position().y > MOUSE_Y_SNAPBACK_THRESHOLD

	if (mouse_motion and mouse_at_bottom) or event.is_action_pressed("right_mouse"):
		_transition(int(CardState.State.BASE))
	elif event.is_action_released("mouse_click") or event.is_action_pressed("mouse_click"):
		get_viewport().set_input_as_handled()
		_transition(int(CardState.State.RELEASED))

func _enter_released() -> void:
	if usable_card == null:
		return
	_released_played = !usable_card.targets.is_empty()
	if _released_played:
		usable_card.activate()

func _released_played_on_enter() -> bool:
	return _released_played

func _enter_selection() -> void:
	if usable_card == null:
		return
	if !usable_card.is_node_ready():
		await usable_card.ready
	usable_card.drop_point_detector.monitoring = false
	usable_card.targets.clear()
	usable_card.card_visuals.glow.hide()
	usable_card.selected = true

func _handle_selection_input(event: InputEvent) -> void:
	if usable_card == null:
		return
	if event.is_action_pressed("mouse_click") and usable_card.is_mouse_over() and usable_card.interaction.needs_more_selections():
		get_viewport().set_input_as_handled()
		Events.card_selection_toggled.emit(usable_card, true)
		_transition(int(CardState.State.SELECTED))

func _enter_selected() -> void:
	if usable_card == null:
		return
	if !usable_card.is_node_ready():
		await usable_card.ready
	usable_card.drop_point_detector.monitoring = false
	usable_card.targets.clear()
	usable_card.card_visuals.glow.show()

func _handle_selected_input(event: InputEvent) -> void:
	if usable_card == null:
		return
	if event.is_action_pressed("mouse_click") and usable_card.is_mouse_over():
		get_viewport().set_input_as_handled()
		Events.card_selection_toggled.emit(usable_card, false)
		_transition(int(CardState.State.SELECTION))
