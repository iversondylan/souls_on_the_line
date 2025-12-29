# melee_attack_action.gd
class_name MeleeAttackAction extends NPCAction

@export var base_damage: int = 5
@export var n_attacks: int = 1
@export var spree_limit: int = 1

func is_performable(_ctx: NPCAIContext) -> bool:
	#var spree: int = int(ctx.state.get("spree", 0))
	#return spree <= spree_limit
	return true

func get_intent_values(ctx: NPCAIContext) -> Dictionary:
	var dmg := ctx.combatant.modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)
	return {
		"dmg": dmg,
		"hits": n_attacks
	}

func perform(ctx: NPCAIContext) -> void:
	ctx.combatant.intent_container.clear_display()
	var fighter := ctx.combatant
	if !fighter:
		fighter.resolve_action()
		return

	var effect := BasicMeleeAttackEffect.new()
	effect.attacker = fighter
	effect.n_damage = base_damage
	effect.n_attacks = n_attacks
	effect.battle_scene = ctx.battle_scene
	effect.sound = sound

	# Update spree state
	ctx.state["spree"] = ctx.state.get("spree", 0) + 1

	effect.execute()

	#" If execute() is synchronous:"
	#I think they're not synchronous. Attack effects do call resolve_action()
	#fighter.resolve_action()
