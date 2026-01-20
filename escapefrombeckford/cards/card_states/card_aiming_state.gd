# card_aiming_state.gd
extends CardState

const MOUSE_Y_SNAPBACK_THRESHOLD := 1060

func enter() -> void:
	#usable_card.state.text = "AIMING"
	usable_card.targets.clear()
	#var offset := Vector2(usable_card.parent.size.x / 2, -usable_card.size.y / 2)
	#offset.x -= card_ui.size.x / 2
	var pos := get_viewport().get_visible_rect().size
	pos.x = pos.x * 0.5
	pos.y = pos.y * 0.75
	usable_card.animate_to_position(pos, 0, 0.2)#card_ui.parent.global_position + offset, 0.2)
	usable_card.drop_point_detector.monitoring = false
	if usable_card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
		Events.battlefield_aim_started.emit(usable_card)
	else:
		Events.card_aim_started.emit(usable_card)

func exit() -> void:
	if usable_card.card_data.target_type == CardData.TargetType.BATTLEFIELD:
		Events.battlefield_aim_ended.emit(usable_card)
	else:
		Events.card_aim_ended.emit(usable_card)

func on_input(event: InputEvent) -> void:
	var mouse_motion := event is InputEventMouseMotion
	var mouse_at_bottom := usable_card.get_global_mouse_position().y > MOUSE_Y_SNAPBACK_THRESHOLD
	
	if (mouse_motion and mouse_at_bottom) or event.is_action_pressed("right_mouse"):
		transition_requested.emit(self, CardState.State.BASE)
	elif event.is_action_released("mouse_click") or event.is_action_pressed("mouse_click"):
		get_viewport().set_input_as_handled()
		transition_requested.emit(self, CardState.State.RELEASED)
