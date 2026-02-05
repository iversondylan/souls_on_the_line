# card_clicked_state.gd
extends CardState

func enter() -> void:
	#print(usable_card.name, " entering ClickedState")
	usable_card.drop_point_detector.monitoring = true

func on_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		transition_requested.emit(self, CardState.State.DRAGGING)
