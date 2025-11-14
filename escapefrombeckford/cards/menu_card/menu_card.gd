class_name MenuCard extends CenterContainer

signal tooltip_requested(card_data: CardData)

@export var card_data: CardData# : set = _set_card_data
@onready var visuals: CardVisuals = $Visuals
var actions: Array[CardAction]

#func _ready() -> void:
	#if card_data:
		#_apply_card_data()

func set_card_data(data: CardData) -> void:
	card_data = data
	if is_node_ready():
		_apply_card_data()
	else:
		await ready
		_apply_card_data()
#func _set_card_data(new_card_data: CardData) -> void:
	#if !is_node_ready():
		#await ready
	#card_data = new_card_data
	#call_deferred("_apply_card_data")

func _apply_card_data() -> void:
	visuals.card_data = card_data
	actions.clear()
	for action_script: GDScript in card_data.actions:
		var new_action: CardAction = action_script.new()
		new_action.card_data = card_data
		actions.push_back(new_action)
	visuals.set_description(get_description())

func get_description() -> String:
	if actions:
		return actions[0].get_unmod_description(card_data.description)
	return "error"

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
