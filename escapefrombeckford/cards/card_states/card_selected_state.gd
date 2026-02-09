# card_selected_state.gd
extends CardState
#class_name CardSelectedState

func enter() -> void:
	if not usable_card.is_node_ready():
		await usable_card.ready

	usable_card.drop_point_detector.monitoring = false
	usable_card.targets.clear()

	# Visual: selected (use your Glow)
	usable_card.card_visuals.glow.show()

func exit() -> void:
	# Don't forcibly hide glow here; SELECTION/Base will decide visuals.
	pass

func on_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click") and usable_card.is_mouse_over():
		get_viewport().set_input_as_handled()
		Events.card_selection_toggled.emit(usable_card, false)
		transition_requested.emit(self, CardState.State.SELECTION)

func on_mouse_entered() -> void:
	# Optional hover pop while selected too
	pass

func on_mouse_exited() -> void:
	pass
