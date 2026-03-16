# sim_attack_runner.gd

class_name SimAttackRunner extends RefCounted

static func run(api: SimBattleAPI, ctx: NPCAIContext) -> bool:
	#print("sim_attack_runner.gd run()")
	if api == null or ctx == null:
		return false
	if ctx.cid <= 0 or !api.is_alive(ctx.cid):
		return false

	var strikes := maxi(int(ctx.params.get(Keys.STRIKES, 1)), 1)
	var any := false
	var mode := int(ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	var targeting := int(ctx.params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	
	# ----------------------------
	# ATTACK SCOPE
	# ----------------------------
	if api.writer != null:
		api.writer.scope_begin(Scope.Kind.ATTACK, "attacker=%d" % int(ctx.cid), int(ctx.cid), {
			Keys.ACTOR_ID: int(ctx.cid),
			Keys.ATTACK_MODE: mode,
			Keys.STRIKES: strikes,
			Keys.TARGET_TYPE: targeting,
		})
	
	# ----------------------------
	# ATTACK_PREP (one-time) with TARGET_IDS
	# ----------------------------
	var prep_target_ids: Array[int] = AttackTargeting.get_target_ids(api, ctx.cid, ctx.params)
	prep_target_ids = prep_target_ids.filter(func(id):
		return int(id) > 0 and api.is_alive(int(id))
	)
	
	#if api.writer != null:
		#api.writer.emit_attack_prep(int(ctx.cid), prep_target_ids, mode, targeting, strikes)
	
	# ----------------------------
	# STRIKES
	# ----------------------------
	for s in range(strikes):
		if !api.is_alive(ctx.cid):
			break
		
		if api.writer != null:
			api.writer.scope_begin(Scope.Kind.STRIKE, "i=%d" % s, int(ctx.cid), {
				Keys.STRIKE_INDEX: s,
				Keys.ATTACK_MODE: mode,
				Keys.TARGET_TYPE: targeting,
			})
		
		# Per-strike target selection (can retarget)
		var target_ids: Array[int] = AttackTargeting.get_target_ids(api, ctx.cid, ctx.params)
		target_ids = target_ids.filter(func(id):
			return int(id) > 0 and api.is_alive(int(id))
		)
		
		if target_ids.is_empty():
			if api.writer != null:
				api.writer.scope_end() # strike
			continue
		
		## ----------------------------
		## STRIKE_WINDUP (per strike)
		## ----------------------------
		#if api.writer != null:
			#api.writer.emit_strike_windup(int(ctx.cid), target_ids, mode, targeting, s)
		#
		## Keep TARGETED too (it’s still useful as “lock-in/telegraph”)
		#if api.writer != null:
			#api.writer.emit_targeted(int(ctx.cid), target_ids, mode, s)
		
		## ----------------------------
		## STRIKE_FOLLOWTHROUGH (per strike)
		## ----------------------------
		#if api.writer != null:
			#api.writer.emit_strike_followthrough(int(ctx.cid), target_ids, mode, targeting, s)
		
		# the real one
		if api.writer != null:
			api.writer.emit_strike(
				int(ctx.cid),
				target_ids,
				mode,
				targeting,
				s,
				strikes,
				String(ctx.params.get(Keys.PROJECTILE_SCENE, ""))
			)
			
		var dmg := 0
		if ctx.params.has(Keys.DAMAGE_MELEE) or ctx.params.has(Keys.DAMAGE_RANGED):
			var k := Keys.DAMAGE_RANGED if mode == Attack.Mode.RANGED else Keys.DAMAGE_MELEE
			dmg = int(ctx.params.get(k, 0))
		else:
			dmg = int(ctx.params.get(Keys.DAMAGE, 0))
		dmg = maxi(dmg, 0)
		#print("sim_attack_runner.gd run() unmod dmg: ", dmg)
		var deal_mod := int(ctx.params.get(Keys.DEAL_MOD_TYPE, Modifier.Type.DMG_DEALT))
		var take_mod := int(ctx.params.get(Keys.TAKE_MOD_TYPE, Modifier.Type.DMG_TAKEN))
		
		for tid: int in target_ids:
			if api.writer != null:
				api.writer.scope_begin(Scope.Kind.HIT, "t=%d" % int(tid), int(ctx.cid), {
					Keys.TARGET_ID: int(tid),
					Keys.STRIKE_INDEX: s,
					Keys.ATTACK_MODE: mode,
				})
			
			var d := DamageContext.new()
			d.source_id = int(ctx.cid)
			d.target_id = int(tid)
			d.base_amount = dmg
			d.deal_modifier_type = deal_mod
			d.take_modifier_type = take_mod
			d.params = ctx.params
			
			(api as SimBattleAPI).resolve_damage_immediate(d)
			any = true

			if api.writer != null:
				api.writer.scope_end() # hit

		
		api.flush_replans()
		if api.writer != null:
			api.writer.scope_end() # strike

	# ----------------------------
	# ATTACK_WRAPUP then end scope
	# ----------------------------
	if api.writer != null:
		api.writer.scope_end() # attack

	return any
