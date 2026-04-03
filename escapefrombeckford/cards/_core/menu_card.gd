class_name MenuCard extends CenterContainer

signal tooltip_requested(card_data: CardData)

@export var card_data: CardData : set = set_card_data
@onready var visuals: CardVisuals = $OuterControl/Visuals

# Must be set by parent (Run / Shop / Collection)
var player_data: PlayerData
var api: SimBattleAPI
var show_battle_modifications := false

func set_card_data(new_card_data: CardData) -> void:
	card_data = new_card_data
	visuals.card_data = card_data
	refresh_description()

func get_description() -> String:
	if show_battle_modifications and api != null:
		return TextUtils.build_battle_card_description(card_data, api)
	return TextUtils.build_card_description(card_data)

func refresh_description() -> void:
	visuals.set_description(get_description())

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
