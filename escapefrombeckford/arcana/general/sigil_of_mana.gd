extends Arcanum

#const ID := "sigil_of_mana"

var member_var := 0

func activate_arcanum(ctx: ArcanumContext) -> void:
	_add_mana(ctx.arcanum_display)

func _add_mana(arcanum_display: ArcanumDisplay) -> void:
	arcanum_display.flash()
	var player := arcanum_display.get_tree().get_first_node_in_group("player") as Player
	if player:
		player.combatant_data.add_mana(1,1,1)
