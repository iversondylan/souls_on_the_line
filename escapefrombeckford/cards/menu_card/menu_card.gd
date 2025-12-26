class_name MenuCard extends CenterContainer

signal tooltip_requested(card_data: CardData)

@export var card_data: CardData : set = set_card_data
@onready var visuals: CardVisuals = $Visuals

func set_card_data(new_card_data: CardData) -> void:
	card_data = new_card_data
	visuals.card_data = card_data
	visuals.set_description(get_description())

func get_description() -> String:
	if card_data.actions.is_empty():
		return card_data.description

	var text := card_data.description
	for action in card_data.actions:
		text = action.get_unmod_description(text)
	return text

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
