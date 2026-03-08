# card_dragging_state.gd
extends CardState

const DRAG_MINIMUM_THRESHOLD := 0.05

var minimum_drag_time_elapsed := false

func enter() -> void:
	#print(usable_card.name, " entering DraggingState")
	usable_card.card_visuals.glow.hide()
	Events.card_drag_started.emit(usable_card)
	
	usable_card.animate_to_rotation(0, 0.2)
	minimum_drag_time_elapsed = false
	var threshold_timer := get_tree().create_timer(DRAG_MINIMUM_THRESHOLD, false)
	threshold_timer.timeout.connect(func(): minimum_drag_time_elapsed = true)

func exit() -> void:
	Events.card_drag_ended.emit(usable_card)

func on_input(event: InputEvent) -> void:
	var single_targeted := usable_card.card_data.is_single_targeted()
	var player_target := usable_card.card_data.target_type == CardData.TargetType.SELF
	var mouse_motion := event is InputEventMouseMotion
	var cancel = event.is_action_pressed("right_mouse")
	var confirm = event.is_action_released("mouse_click") or event.is_action_pressed("mouse_click")
	
	if single_targeted and mouse_motion and usable_card.targets.size() > 0:
		transition_requested.emit(self, CardState.State.AIMING)
		return
	
	if player_target and mouse_motion and usable_card.targets.size() > 0:
		Events.player_targeted_arrow_visible.emit(true)
		#player.show_targeted_arrow()
	
	if player_target and mouse_motion and usable_card.targets.size() == 0:
		Events.player_targeted_arrow_visible.emit(false)
		#player.hide_targeted_arrow()
	
	if mouse_motion:
		#print("card_dragging_state.gd updating position")
		usable_card.global_position = usable_card.get_global_mouse_position()
	
	if cancel:
		Events.player_targeted_arrow_visible.emit(false)
		transition_requested.emit(self, CardState.State.BASE)
	elif minimum_drag_time_elapsed and confirm:
		Events.player_targeted_arrow_visible.emit(false)
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)
