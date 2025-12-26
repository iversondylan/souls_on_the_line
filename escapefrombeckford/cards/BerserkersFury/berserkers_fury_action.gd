extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1

func activate(ctx: CardActionContext) -> bool:
	var attackers := ctx.resolved_target.fighters
	if attackers.is_empty():
		return false

	# Berserker's Fury always targets a summoned ally
	var attacker: Fighter = attackers[0]

	# Base damage scales from the ALLY, not the player
	var base_damage := attacker.combatant_data.max_mana_red + bonus_damage

	# Apply the ally's DMG_DEALT modifiers
	var final_damage := attacker.modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)

	var attack_effect := BasicMeleeAttackEffect.new()
	attack_effect.target_type = AttackEffect.TargetType.ALL_OPPONENTS
	attack_effect.attacker = attacker
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
	# If hovering a valid ally, preview with that ally's modifiers
	if !ctx.resolved_target.fighters.is_empty():
		var ally: Fighter = ctx.resolved_target.fighters[0]

		var base_damage := ally.combatant_data.max_mana_red + bonus_damage
		var modified_damage := ally.modifier_system.get_modified_value(
			base_damage,
			Modifier.Type.DMG_DEALT
		)

		return [modified_damage]

	# Otherwise, show an unmodified baseline preview
	# (no ally hovered yet)
	var baseline_damage := ctx.player.combatant_data.max_mana_red + bonus_damage
	return [baseline_damage]
