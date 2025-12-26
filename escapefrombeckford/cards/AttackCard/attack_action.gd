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

func description_arity() -> int:
	return 1

func get_description_values(ctx: CardActionContext) -> Array:
	
	var damage := ctx.player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	var target: Fighter = null
	if !ctx.resolved_target.fighters.is_empty():
		target = ctx.resolved_target.fighters[0]
	if target:
		damage = target.modifier_system.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
	
	return [damage]

#func get_description(ctx: CardActionContext, base_text: String) -> String:
	#var damage := ctx.player.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
#
	#var target: Fighter = null
	#if !ctx.resolved_target.fighters.is_empty():
		#target = ctx.resolved_target.fighters[0]
	#if target:
		#damage = target.modifier_system.get_modified_value(damage, Modifier.Type.DMG_TAKEN)
#
	#return base_text % str(damage)
#
#
#func get_unmod_description(description: String) -> String:
	#return description % str(base_damage)
