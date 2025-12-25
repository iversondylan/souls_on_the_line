extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1

func activate(ctx: CardActionContext) -> bool:
	var attackers := ctx.resolved_target.fighters
	if attackers.is_empty():
		return false

	var attacker := attackers[0]

	var attack_damage := attacker.combatant_data.max_mana_red + bonus_damage

	var attack_effect := BasicMeleeAttackEffect.new()
	attack_effect.target_type = AttackEffect.TargetType.ALL_OPPONENTS
	attack_effect.attacker = attacker
	attack_effect.n_damage = attack_damage
	attack_effect.n_attacks = attacks
	attack_effect.explode = true
	attack_effect.battle_scene = ctx.battle_scene
	attack_effect.sound = ctx.card_data.sound
	attack_effect.execute()

	return true


func get_description(description: String, target: Fighter = null) -> String:
	if !target:
		return description
	return description % [str(target.combatant_data.max_mana_red + bonus_damage), ""]



func get_unmod_description(description: String) -> String:
	return description % ["Power", "+" + str(bonus_damage)]
