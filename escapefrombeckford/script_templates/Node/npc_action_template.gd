# meta-name: NPCAction
# meta-description: Create an action script for an NPCAction node

# my_new_npc_action.gd
class_name MyNewNPCAction
extends NPCAction

@export_group("Attack Parameters")
@export var base_damage: int = 5
@export var n_attacks: int = 1

@export_group("Behavior")
@export var spree_limit: int = 1

func is_performable(ctx: NPCAIContext) -> bool:
	var spree: int = int(ctx.state.get("spree", 0))
	return spree <= spree_limit

func get_intent_values(ctx: NPCAIContext) -> Dictionary:
	var modified_damage: int = ctx.combatant.modifier_system.get_modified_value(
		base_damage,
		Modifier.Type.DMG_DEALT
	)

	return {
		"dmg": modified_damage,
		"hits": n_attacks
	}

func get_tooltip(ctx: NPCAIContext) -> String:
	var values: Dictionary = get_intent_values(ctx)
	var dmg: int = int(values.get("dmg", 0))
	var hits: int = int(values.get("hits", 1))

	if hits == 1:
		return "[center]This character will deal %s damage.[/center]" % dmg
	elif hits == 2:
		return "[center]This character will deal %s damage twice.[/center]" % dmg
	else:
		return "[center]This character will deal %s damage %s times.[/center]" % [dmg, hits]



func perform(ctx: NPCAIContext) -> void:
	var fighter := ctx.combatant
	if !fighter:
		return

	# Update AI state
	ctx.state["spree"] = int(ctx.state.get("spree", 0)) + 1

	#var effect := BasicMeleeAttackEffect.new()
	#effect.attacker = fighter
	#effect.n_damage = base_damage
	#effect.n_attacks = n_attacks
	#effect.battle_scene = ctx.battle_scene
	##effect.sound = sound
#
	#effect.execute(BattleAPI.new())
#
	## IMPORTANT: always resolve
	#fighter.resolve_action()


func save_state(ctx: NPCAIContext) -> Dictionary:
	return {
		"spree": int(ctx.state.get("spree", 0))
	}

func load_state(ctx: NPCAIContext, data: Dictionary) -> void:
	ctx.state["spree"] = int(data.get("spree", 0))
