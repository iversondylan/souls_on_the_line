class_name NPCAttackAction extends NPCAction

enum AttackMode {
	MELEE,
	RANGED
}

@export_group("Models")
@export var mode_model: NPCAttackModeModel
@export var damage_model: NPCDamageModel
@export var strikes_model: NPCStrikesModel


@export_group("Effects")
@export var melee_effect: NPCAttackEffect
@export var ranged_effect: NPCAttackEffect

func get_intent_values(ctx: NPCAIContext) -> Dictionary:
	var dmg := damage_model.get_damage(ctx)
	var strikes := strikes_model.get_strikes(ctx)
	return {
		"dmg": dmg,
		"strikes": strikes
	}

func perform(ctx: NPCAIContext) -> void:
	var fighter := ctx.combatant
	if not fighter:
		fighter.resolve_action()
		return

	var mode := AttackMode.MELEE
	if mode_model:
		mode = mode_model.resolve_mode(ctx)

	var effect: NPCAttackEffect
	match mode:
		AttackMode.MELEE:
			effect = melee_effect
		AttackMode.RANGED:
			effect = ranged_effect

	if not effect:
		fighter.resolve_action()
		return

	# Configure effect
	effect.attacker = fighter
	effect.damage = damage_model.get_damage(ctx)
	effect.strikes = strike_model.get_strikes(ctx)
	effect.battle_scene = ctx.battle_scene
	effect.sound = sound

	if spree_model:
		spree_model.increment(ctx)

	effect.execute()
