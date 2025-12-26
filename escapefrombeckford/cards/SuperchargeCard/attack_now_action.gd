extends CardAction

@export var attacks: int = 1
#@export var damage_source := DamageSource.MAX_RED_MANA
# You can later make this an enum if you want flexibility

func activate(ctx: CardActionContext) -> bool:
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false

	var attacker := targets[0]

	var attack_effect := BasicMeleeAttackEffect.new()
	attack_effect.attacker = attacker
	attack_effect.n_attacks = attacks
	attack_effect.battle_scene = ctx.battle_scene
	attack_effect.sound = ctx.card_data.sound
	attack_effect.n_damage = attacker.combatant_data.max_mana_red
	
	attack_effect.execute()
	return true

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
