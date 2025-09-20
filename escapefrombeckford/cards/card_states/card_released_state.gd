extends CardState

var played: bool

func enter() -> void:
	usable_card.state.text = "RELEASED"
	#print("card_released_state.gd enter()")
	played = false

	if !usable_card.targets.is_empty():
		played = usable_card.activate()
	

	
	#THIS SHOULD PROBABLY BE REPLACED LATER
	#transition_requested.emit(self, CardState.State.BASE)

func dwell() -> void:
	print("card_released_state.gd dwell()")
	transition_requested.emit(self, CardState.State.BASE)

func on_input(_event: InputEvent) -> void:
	print("card_released_state.gd on_input()")
	if played:
		return
	
	transition_requested.emit(self, CardState.State.BASE)
