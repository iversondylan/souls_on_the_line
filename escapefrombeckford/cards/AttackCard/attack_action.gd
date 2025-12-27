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
	var base := base_damage
	# Prefer live player (modifiers)
	if ctx.player:
		base = ctx.player.modifier_system.get_modified_value(base, Modifier.Type.DMG_DEALT)
	elif ctx.player_data:
		# Optional: preview using PlayerData if you want
		base = base_damage  # or derived from player_data later
	# Apply target-side preview if present
	if ctx.resolved_target and !ctx.resolved_target.fighters.is_empty():
		var target := ctx.resolved_target.fighters[0]
		if target and target.modifier_system:
			base = target.modifier_system.get_modified_value(base, Modifier.Type.DMG_TAKEN)
	return [base]
