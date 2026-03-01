# sim_attack_runner.gd

class_name SimAttackRunner extends RefCounted

static func run(api: SimBattleAPI, ctx: NPCAIContext) -> bool:
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
		# func scope_begin(kind: int, label: String = "", actor_id: int = 0, data := {}) -> int:
		api.writer.scope_begin(Scope.Kind.ATTACK, "attacker=%d" % int(ctx.cid), int(ctx.cid), {
			#Keys.ACTOR_ID: ctx.cid,
			Keys.ATTACK_MODE: mode,
			Keys.STRIKES: strikes,
			Keys.TARGET_TYPE: targeting
		})
	
	for _s in range(strikes):
		if !api.is_alive(ctx.cid):
			break
		
		# ----------------------------
		# STRIKE SCOPE
		# ----------------------------
		if api.writer != null:
			api.writer.scope_begin(Scope.Kind.STRIKE, "i=%d" % _s, int(ctx.cid), {
				Keys.STRIKE_INDEX: _s,
			})
		
		var target_ids: Array[int] = AttackTargeting.get_target_ids(api, ctx.cid, ctx.params)

		target_ids = target_ids.filter(func(id):
			return int(id) > 0 and api.is_alive(int(id))
		)
		if target_ids.is_empty():
			if api.writer != null:
				api.writer.scope_end() # strike
			continue
		
		if api.writer != null:
			# func emit_targeted(attacker_id: int, target_ids: Array[int], attack_mode: int, strike_index: int, extra := {}) -> void:
			api.writer.emit_targeted(int(ctx.cid), target_ids, mode, _s)
		
		var dmg := 0
		if ctx.params.has(Keys.DAMAGE_MELEE) or ctx.params.has(Keys.DAMAGE_RANGED):
			var k := Keys.DAMAGE_RANGED if mode == Attack.Mode.RANGED else Keys.DAMAGE_MELEE
			dmg = int(ctx.params.get(k, 0))
		else:
			dmg = int(ctx.params.get(Keys.DAMAGE, 0))

		dmg = maxi(dmg, 0)

		var deal_mod := int(ctx.params.get(Keys.DEAL_MOD_TYPE, Modifier.Type.DMG_DEALT))
		var take_mod := int(ctx.params.get(Keys.TAKE_MOD_TYPE, Modifier.Type.DMG_TAKEN))
		
		# an attacker's STRIKE may result in multiple HITS on its targets.
		# hit loop:
		for tid: int in target_ids:
			
			# ----------------------------
			# HIT SCOPE (per target)
			# ----------------------------
			if api.writer != null:
				api.writer.scope_begin(Scope.Kind.HIT, "t=%d" % int(tid), int(ctx.cid), {
					#Keys.ACTOR_ID: ctx.cid,
					Keys.TARGET_ID: tid,
					Keys.STRIKE_INDEX: _s,
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
		if api.writer != null:
			api.writer.scope_end() # strike
	if api.writer != null:
		api.writer.scope_end() # attack

	return any
