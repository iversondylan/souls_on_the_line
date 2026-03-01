# sim_npc_attack_sequence.gd

# use like: return SimNPCAttackSequence.run(ctx)

class_name SimNPCAttackSequence extends RefCounted

static func run(ctx: NPCAIContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var attacker_id := 0
	if ctx.combatant:
		attacker_id = int(ctx.combatant.combat_id)
	elif ctx.combatant_data:
		attacker_id = int(ctx.combatant_data.combat_id)

	if attacker_id <= 0:
		return false

	var spec := SimAttackSpec.new()
	spec.attacker_id = attacker_id
	spec.strikes = int(ctx.params.get(Keys.STRIKES, 1))
	spec.base_damage = int(ctx.params.get(Keys.DAMAGE, 0))
	spec.params = ctx.params # (shared dict is fine if you treat it as read-only here)

	return ctx.api.resolve_attack(spec)
