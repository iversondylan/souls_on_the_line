# sim_attack_runner.gd

class_name SimAttackRunner extends RefCounted

static func run(api, ctx: NPCAIContext) -> bool:
	if api == null or ctx == null:
		return false
	if ctx.cid <= 0 or !api.is_alive(ctx.cid):
		return false

	var strikes := maxi(int(ctx.params.get(NPCKeys.STRIKES, 1)), 1)
	var any := false

	for _s in range(strikes):
		if !api.is_alive(ctx.cid):
			break

		var target_ids: Array[int] = AttackTargeting.get_target_ids(api, ctx.cid, ctx.params)

		target_ids = target_ids.filter(func(id):
			return int(id) > 0 and api.is_alive(int(id))
		)
		if target_ids.is_empty():
			continue

		var mode := int(ctx.params.get(NPCKeys.ATTACK_MODE, Attack.Mode.MELEE))

		var dmg := 0
		if ctx.params.has(NPCKeys.DAMAGE_MELEE) or ctx.params.has(NPCKeys.DAMAGE_RANGED):
			var k := NPCKeys.DAMAGE_RANGED if mode == Attack.Mode.RANGED else NPCKeys.DAMAGE_MELEE
			dmg = int(ctx.params.get(k, 0))
		else:
			dmg = int(ctx.params.get(NPCKeys.DAMAGE, 0))

		dmg = maxi(dmg, 0)

		var deal_mod := int(ctx.params.get(NPCKeys.DEAL_MOD_TYPE, Modifier.Type.DMG_DEALT))
		var take_mod := int(ctx.params.get(NPCKeys.TAKE_MOD_TYPE, Modifier.Type.DMG_TAKEN))

		for tid in target_ids:
			var d := DamageContext.new()
			d.source_id = int(ctx.cid)
			d.target_id = int(tid)
			d.base_amount = dmg
			d.deal_modifier_type = deal_mod
			d.take_modifier_type = take_mod
			d.params = ctx.params

			(api as SimBattleAPI).resolve_damage_immediate(d)
			any = true

	return any

#static func run(api, ctx: NPCAIContext) -> bool:
	#print("sim_attack_runner.gd run() attacker=%d alive=%s strikes=%d dmg_r=%d dmg_m=%s"
	#% [ctx.cid, str(api.is_alive(ctx.cid)), ctx.params.get(NPCKeys.STRIKES, 1), ctx.params.get(NPCKeys.DAMAGE_RANGED, 0), ctx.params.get(NPCKeys.DAMAGE_MELEE, 0)])
	#if api == null or ctx == null:
		#return false
	#if ctx.cid <= 0 or !api.is_alive(ctx.cid):
		#return false
	#
	#var strikes := maxi(int(ctx.params.get(NPCKeys.STRIKES, 1)), 1)
	#var any := false
	#
	#for _s in range(strikes):
		#if !api.is_alive(ctx.cid):
			#break
		#print("sim_attack_runner.gd run() strike=%d/%d"
		#% [_s+1, strikes])
		#var target_ids: Array[int] = []
		#target_ids = AttackTargeting.get_target_ids(api, ctx.cid, ctx.params)
		#
		## Alive filter
		#target_ids = target_ids.filter(func(id): return int(id) > 0 and api.is_alive(int(id)))
		#if target_ids.is_empty():
			#continue
		#
		#
		#var mode := int(ctx.params.get(NPCKeys.ATTACK_MODE, Attack.Mode.MELEE))
		#var dmg := 0
		#
		#if ctx.params.has(NPCKeys.DAMAGE_MELEE) or ctx.params.has(NPCKeys.DAMAGE_RANGED):
			#dmg = int(ctx.params.get(NPCKeys.DAMAGE_RANGED if mode == Attack.Mode.RANGED else NPCKeys.DAMAGE_MELEE, dmg))
		#else:
			#dmg = int(ctx.params.get(NPCKeys.DAMAGE, dmg))
		#for tid in target_ids:
			#var d := DamageContext.new()
			#d.source_id = int(ctx.cid)
			#d.target_id = int(tid)
			#d.base_amount = dmg
			#d.deal_modifier_type = int(ctx.params.get(NPCKeys.DEAL_MOD_TYPE, Modifier.Type.DMG_DEALT))
			#d.take_modifier_type = int(ctx.params.get(NPCKeys.TAKE_MOD_TYPE, Modifier.Type.DMG_TAKEN))
			#d.params = ctx.params
			#
			#(api as SimBattleAPI).resolve_damage_immediate(d)
			#any = true
#
	#return any
