# sim_status_event_runner.gd

class_name SimStatusEventRunner extends RefCounted

static func on_damage_taken(api: SimBattleAPI, ctx: DamageContext) -> void:
	if api == null or api.state == null or ctx == null:
		return
	if int(ctx.target_id) <= 0:
		return
	
	var tid := int(ctx.target_id)
	var u: CombatantState = api.state.get_unit(tid)
	if u == null or !u.is_alive():
		return
	if u.statuses == null or u.statuses.by_id == null or u.statuses.by_id.is_empty():
		return
	
	# Only health damage should reduce stability (matches your live semantics)
	var hp_dmg := maxi(int(ctx.health_damage), 0)
	if hp_dmg <= 0:
		return
	
	# --- Stability special-case (fast path) ---
	var stab_id: StringName = &"stability"
	if !u.statuses.by_id.has(stab_id):
		return
	
	var stack: StatusStack = u.statuses.by_id.get(stab_id, null)
	if stack == null:
		return
	
	var before_i := int(stack.intensity)
	var before_d := int(stack.duration)
	
	# Apply damage to stability
	stack.intensity = before_i - hp_dmg
	var after_i := int(stack.intensity)
	
	# Emit CHANGE (delta intensity is negative; duration unchanged)
	if api.writer != null:
		api.writer.emit_status(
			tid,                # source_id (self-inflicted for this special rule)
			tid,                # target_id
			stab_id,
			int(Status.OP.CHANGE),
			-hp_dmg,            # intensity delta
			0,                  # duration delta (unchanged)
			{
				# Optional, but nice for debugging / schedulers
				Keys.DELTA_INTENSITY: -hp_dmg,
				Keys.DELTA_DURATION: 0,
				Keys.BEFORE_INTENSITY: before_i,
				Keys.AFTER_INTENSITY: after_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_DURATION: int(stack.duration),
				Keys.REASON: "damage_taken",
			}
		)
	
	# Break stability: remove status + mark AI state
	if after_i <= 0:
		u.statuses.by_id.erase(stab_id)
		
		if u.ai_state == null:
			u.ai_state = {}
		u.ai_state[Keys.STABILITY_BROKEN] = true
		
		# Emit REMOVE so view/scheduler can clear icon
		if api.writer != null:
			api.writer.emit_status(
				tid,
				tid,
				stab_id,
				int(Status.OP.REMOVE),
				0,
				0,
				{
					Keys.REASON: "stability_broken",
				}
			)
		
		# Overeager reaction: replan now (unless acting guard blocks it)
		api._request_replan(tid)
		api._request_intent_refresh(tid)
