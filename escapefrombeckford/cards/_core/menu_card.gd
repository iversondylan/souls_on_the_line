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
	refresh_battle_visuals()

func get_description() -> String:
	if show_battle_modifications and api != null:
		return TextUtils.build_battle_card_description(card_data, api)
	return TextUtils.build_card_description(card_data)

func refresh_description() -> void:
	visuals.set_description(get_description())

func refresh_battle_visuals() -> void:
	_apply_battle_summon_stat_bonuses()
	refresh_description()

func _apply_battle_summon_stat_bonuses() -> void:
	if visuals == null:
		return
	if !show_battle_modifications or api == null or !_should_query_summon_stat_bonuses():
		visuals.set_summon_card_stat_bonuses(0, 0)
		return
	card_data.ensure_uid()
	visuals.set_summon_card_stat_bonuses(
		api.get_summon_card_ap_bonus(String(card_data.uid)),
		api.get_summon_card_max_health_bonus(String(card_data.uid))
	)

func _should_query_summon_stat_bonuses() -> bool:
	if card_data == null:
		return false
	return int(card_data.card_type) == int(CardData.CardType.SOULBOUND) \
		or int(card_data.card_type) == int(CardData.CardType.SOULWILD)

func _on_visuals_mouse_entered() -> void:
	visuals.glow.show()

func _on_visuals_mouse_exited() -> void:
	visuals.glow.hide()

func _on_visuals_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		tooltip_requested.emit(card_data)
