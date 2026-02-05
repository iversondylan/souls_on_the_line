# card_selection_state.gd
extends CardState
#class_name CardSelectionState

func enter() -> void:
	#print(usable_card.name, " entering SelectionState")
	if not usable_card.is_node_ready():
		await usable_card.ready

	# Make sure we are NOT in play/drag mode.
	usable_card.drop_point_detector.monitoring = false
	usable_card.targets.clear()

	# Visual: not selected
	usable_card.card_visuals.glow.hide()
	usable_card.selected = true # IMPORTANT: so BaseState gating doesn't matter for click detection elsewhere

func on_input(event: InputEvent) -> void:
	# Only care about left click while mouse is over card
	if event.is_action_pressed("mouse_click") and usable_card.is_mouse_over():
		get_viewport().set_input_as_handled()
		Events.card_selection_toggled.emit(usable_card, true)
		transition_requested.emit(self, CardState.State.SELECTED)

func on_mouse_entered() -> void:
	# Optional: pop/enlarge on hover. If you want it, call:
	# usable_card.enlarge_visuals()
	pass

func on_mouse_exited() -> void:
	# Optional: reset visuals if using enlarge
	# usable_card.reset_visuals()
	pass
