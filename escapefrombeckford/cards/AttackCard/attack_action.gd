extends CardAction

@export var base_damage: int = 5
@export var attack_count: int = 1   # kept for future extensibility

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	# Damage is computed from the ATTACKER (player)
	var attacker := ctx.player
	var damage := attacker.modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)

	var damage_effect := DamageEffect.new()
	damage_effect.targets = targets
	damage_effect.n_damage = damage
	damage_effect.sound = ctx.card_data.sound
	damage_effect.execute()

	return true


func get_description(description: String, target_fighter: Fighter = null) -> String:
	# Preview damage using the player as the source
	var damage := ctx_preview_player().modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)

	# If a target is known, preview mitigation as well
	if target_fighter:
		damage = target_fighter.modifier_system.get_modified_value(
			damage,
			Modifier.Type.DMG_TAKEN
		)

	return description % str(damage)


func get_unmod_description(description: String) -> String:
	return description % str(base_damage)
