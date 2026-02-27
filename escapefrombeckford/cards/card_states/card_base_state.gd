# card_base_state.gd

class_name BaseState extends CardState

func enter() -> void:
	if not usable_card.is_node_ready():
		await  usable_card.ready
	
	usable_card.card_visuals.glow.hide()
	usable_card.card_fan_requested.emit(usable_card)

func on_input(event: InputEvent) -> void:
	if !usable_card.playable or usable_card.disabled:
		return
	
	if event.is_action_pressed("mouse_click") and usable_card.selected:
		#print("card_base_state.gd updating position")
		usable_card.global_position = usable_card.get_global_mouse_position()
		transition_requested.emit(self, CardState.State.CLICKED)
