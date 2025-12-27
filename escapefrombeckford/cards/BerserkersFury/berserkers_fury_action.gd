extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1

func activate(ctx: CardActionContext) -> bool:
	var attackers := ctx.resolved_target.fighters
	if attackers.is_empty():
		return false

	# Berserker's Fury always targets a summoned ally
	var ally: Fighter = attackers[0]

	# Base damage scales from the ALLY
	var base_damage := ally.combatant_data.max_mana_red + bonus_damage

	# Apply the ally's outgoing damage modifiers
	var final_damage := ally.modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)

	var attack_effect := BasicMeleeAttackEffect.new()
	attack_effect.target_type = AttackEffect.TargetType.ALL_OPPONENTS
	attack_effect.attacker = ally
	attack_effect.n_damage = final_damage
	attack_effect.n_attacks = attacks
	attack_effect.explode = true
	attack_effect.battle_scene = ctx.battle_scene
	attack_effect.sound = ctx.card_data.sound
	attack_effect.execute()

	return true


func description_arity() -> int:
	return 1


func get_description_values(ctx: CardActionContext) -> Array:
	# Case 1: hovering a valid ally → show fully modified value
	if ctx.resolved_target and !ctx.resolved_target.fighters.is_empty():
		var ally: Fighter = ctx.resolved_target.fighters[0]

		var base_damage := ally.combatant_data.max_mana_red + bonus_damage
		var modified_damage := ally.modifier_system.get_modified_value(
			base_damage,
			Modifier.Type.DMG_DEALT
		)

		return [modified_damage]

	# Case 2: no ally hovered → baseline preview (no modifiers)
	# Prefer player_data if player is not instantiated
	if ctx.player:
		return [ctx.player.combatant_data.max_mana_red + bonus_damage]

	if ctx.player_data:
		return [ctx.player_data.max_mana_red + bonus_damage]

	# Absolute fallback (should be rare)
	return [bonus_damage]
