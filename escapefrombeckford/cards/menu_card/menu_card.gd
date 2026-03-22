class_name MenuCard extends CenterContainer

signal tooltip_requested(card_data: CardData)

@export var card_data: CardData : set = set_card_data
@onready var visuals: CardVisuals = $Visuals

# Must be set by parent (Run / Shop / Collection)
var player_data: PlayerData

func set_card_data(new_card_data: CardData) -> void:
	card_data = new_card_data
	visuals.card_data = card_data
	visuals.set_description(get_description())

func get_description() -> String:
	return TextUtils.build_card_description(card_data)

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
