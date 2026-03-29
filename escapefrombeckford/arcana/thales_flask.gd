# thales_flask.gd

extends Arcanum

const ID := &"thales_flask"

@export var n_heal := 6
#
func on_battle_ended(api: SimBattleAPI) -> void:
	if api == null:
		return

	var player_id := int(api.get_player_id())
	if player_id <= 0:
		return

	var heal_ctx := HealContext.new(player_id, player_id, int(n_heal), 0.0, 0.0)
	api.heal(heal_ctx)

func get_id() -> StringName:
	return ID

#func deactivate_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	#print("arcanum.gd deactivate_arcanum(): this gets called when an ArcanumDisplay is exiting scene tree.")
	#print("Event-based arcana should disconnect from Events bus here.")
#
## we can provide unique tooltips per arcanum
#func get_tooltip() -> String:
	#return tooltip_description
#
