class_name BaseState extends CardState

func enter() -> void:
	if not usable_card.is_node_ready():
		await  usable_card.ready
	
	#if usable_card.tween and usable_card.tween.is_running():
		#usable_card.tween.kill()
	
	usable_card.card_visuals.glow.hide()
	usable_card.reparent_requested.emit(usable_card)
	#usable_card.state.text = "BASE"
	#usable_card.pivot_offset = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if !usable_card.playable or usable_card.disabled:
		return
	
	if event.is_action_pressed("mouse_click"):
		print("card_base_state.gd _input() selected = %s" % usable_card.selected)
	if event.is_action_pressed("mouse_click") and usable_card.selected:
		usable_card.global_position = usable_card.get_global_mouse_position()
		#usable_card.pivot_offset = usable_card.get_global_mouse_position() - usable_card.global_position
		transition_requested.emit(self, CardState.State.CLICKED)

#func on_mouse_entered() -> void:
	##print("card_base_state.gd on_mouse_entered()")
	#if !usable_card.playable or usable_card.disabled:
		#return
	#usable_card.card_visuals.glow.show()

#func on_mouse_exited() -> void:
	#if !usable_card.playable or usable_card.disabled:
		#return
	#usable_card.card_visuals.glow.hide()
