# stupid temporary hack runner.gd

# sim_status_event_runner.gd

class_name SimStatusEventRunner extends RefCounted

static func on_damage_taken(api: SimBattleAPI, ctx: DamageContext) -> void:
	print("sim_status_event_runner.gd on_damage_taken() dmg: %s" % [ctx.amount])
	if api == null or api.state == null or ctx == null:
		return
	if int(ctx.target_id) <= 0:
		return
	
	var tid := int(ctx.target_id)
	var u: CombatantState = api.state.get_unit(tid)
	if u == null or !u.is_alive():
		return
	if u.statuses == null or u.statuses.by_id.is_empty():
		return
	
	# Only health damage should reduce stability (matches your live semantics)
	var hp_dmg := maxi(int(ctx.health_damage), 0)
	if hp_dmg <= 0:
		return
	
	# --- Stability special-case (fast path) ---
	var stab_id: StringName = &"stability"
	if u.statuses.by_id.has(stab_id):
		var stack: StatusStack = u.statuses.by_id[stab_id]
		if stack != null:
			stack.intensity = int(stack.intensity) - hp_dmg
			# after stack.intensity -= hp_dmg
			
			if api.writer != null:
				api.writer.emit_status_changed(tid, tid, stab_id, int(stack.intensity), int(stack.duration))
			if int(stack.intensity) <= 0:
				# Break stability: remove status + mark AI state
				u.statuses.by_id.erase(stab_id)
				
				if u.ai_state == null:
					u.ai_state = {}
				u.ai_state[Keys.STABILITY_BROKEN] = true
				
				# Optional: emit removal event so VIEW updates
				if api.writer != null:
					api.writer.emit_status_removed(tid, tid, stab_id, 1, true)
				
				# Overeager reaction: replan now (unless acting guard blocks it)
				api._request_replan(tid)
				
				# Optional: if currently acting, request an interrupt (future work)
				# u.ai_state[&"interrupt_requested"] = true
