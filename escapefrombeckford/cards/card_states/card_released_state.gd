# card_released_state.gd
extends CardState

var played: bool

func enter() -> void:
	played = false

	if !usable_card.targets.is_empty():
		played = usable_card.activate()

func dwell() -> void:
	transition_requested.emit(self, CardState.State.BASE)

func on_input(_event: InputEvent) -> void:
	if played:
		return
	
	transition_requested.emit(self, CardState.State.BASE)
