# thales_flask.gd

extends Arcanum

const ID := &"thales_flask"

@export var n_heal := 6
#
#func initialize_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	#print("arcanum.gd initialize_arcanum(): This happens once when arcanum is acquired.")

func activate_arcanum(ctx: ArcanumContext) -> Variant:
	var player := ctx.arcanum_display.get_tree().get_first_node_in_group("player") as Player
	if player:
		player.heal(n_heal)
		arcanum_display.flash()
	return null

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
