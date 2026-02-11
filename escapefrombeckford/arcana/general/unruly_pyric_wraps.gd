extends Arcanum

var damage := 2

func activate_arcanum(ctx: ArcanumContext) -> void:
	var enemies: Array[Fighter] = []
	for node: Node in arcanum_display.get_tree().get_nodes_in_group("enemies"):
		if node is Fighter:
			enemies.push_back(node)
		else:
			print("unruly_pyric_wraps.gd error: node is not Fighter")
	var damage_effect := DamageEffect.new()
	damage_effect.targets = enemies
	damage_effect.n_damage = damage
	damage_effect.modifier_type = Modifier.Type.NO_MODIFIER
	damage_effect.execute(ctx.api)
	arcanum_display.flash()
