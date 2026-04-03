# sim_runtime.gd

class_name SimRuntime extends RefCounted

# Runtime orchestration for a single Sim.
#
# Responsibilities:
# - own TurnEngineCore and TurnFlowQueryHost for this Sim
# - own turn-flow orchestration for this Sim
# - emit scoped BattleEventLog runtime events
# - define checkpoint boundaries for the turn flow
# - drive round-to-round scheduling
# - own runtime-only execution orchestration and scope lifecycle
#
# Structural ownership still lives in SimHost:
# - SimHost owns main/preview sims
# - SimRuntime owns runtime execution for one Sim

var sim: Sim
var host: SimHost

var turn_engine: TurnEngineCore
var turn_flow_query_host: TurnFlowQueryHost
var _group_turn_scope_handle: ScopeHandle = null
var _actor_turn_scope_handle: ScopeHandle = null
var _delayed_reactions_by_timing: Dictionary = {}
var _strike_resolution_depth: int = 0
var _active_delayed_reaction_drains: Dictionary = {}
var _active_delayed_reaction: DelayedReaction = null


# ============================================================================
# Binding / lifecycle
# ============================================================================

func _init(_sim: Sim = null, _host: SimHost = null) -> void:
	sim = _sim
	host = _host


func bind(_sim: Sim, _host: SimHost) -> void:
	sim = _sim
	host = _host


func reset_runtime_state() -> void:
	turn_engine = null
	turn_flow_query_host = null
	_group_turn_scope_handle = null
	_actor_turn_scope_handle = null
	_delayed_reactions_by_timing.clear()
	_strike_resolution_depth = 0
	_active_delayed_reaction_drains.clear()
	_active_delayed_reaction = null

func _ensure_turn_flow_query_host_initialized() -> void:
	if host == null:
		return

	if turn_flow_query_host == null:
		turn_flow_query_host = TurnFlowQueryHost.new(sim, host)
	else:
		turn_flow_query_host.bind(sim, host)

func _ensure_runtime_initialized() -> void:
	_ensure_turn_flow_query_host_initialized()

	if turn_engine != null:
		return

	turn_engine = TurnEngineCore.new(turn_flow_query_host)

func clone_turn_flow_from(source_runtime: SimRuntime) -> bool:
	if source_runtime == null or source_runtime.turn_engine == null:
		return false

	_ensure_turn_flow_query_host_initialized()
	if turn_flow_query_host == null:
		return false

	turn_engine = source_runtime.turn_engine.clone_for_host(turn_flow_query_host)
	return true


# ============================================================================
# Small helpers
# ============================================================================

func _api() -> SimBattleAPI:
	return sim.api if sim != null else null


func _writer() -> BattleEventWriter:
	var api := _api()
	return api.writer if api != null else null


func _engine() -> TurnEngineCore:
	return turn_engine


func _player_id() -> int:
	if turn_flow_query_host == null:
		return 0
	return turn_flow_query_host.get_player_id()


func _can_run() -> bool:
	return sim != null and sim.api != null and host != null


func _supports_single_target_spillthrough(targeting: int, target_ids: Array[int]) -> bool:
	if target_ids.size() != 1:
		return false
	return int(targeting) == int(Attack.Targeting.STANDARD) or int(targeting) == int(Attack.Targeting.REVERSE)


func _unit_can_enable_spillthrough(api: SimBattleAPI, attacker_id: int, primary_target_id: int) -> bool:
	if api == null:
		return false
	return SimStatusSystem.unit_grants_attack_spillthrough(api, int(attacker_id)) or SimStatusSystem.unit_grants_received_spillthrough(api, int(primary_target_id))


func _should_apply_spillthrough(
	api: SimBattleAPI,
	ctx: AttackContext,
	targeting: int,
	target_ids: Array[int],
	primary_target_id: int,
	next_target_id: int,
	damage_ctx: DamageContext
) -> bool:
	if api == null or ctx == null or damage_ctx == null:
		return false
	var supports := _supports_single_target_spillthrough(targeting, target_ids)
	var ids_ok := int(primary_target_id) > 0 and int(next_target_id) > 0
	var lethal := bool(damage_ctx.was_lethal)
	var overflow := int(damage_ctx.overflow_amount)
	var next_alive := bool(api.is_alive(int(next_target_id))) if int(next_target_id) > 0 else false
	var attack_enabled := false
	var target_enabled := false
	if supports and ids_ok and lethal and overflow > 0 and next_alive:
		attack_enabled = SimStatusSystem.unit_grants_attack_spillthrough(api, int(ctx.attacker_id))
		target_enabled = SimStatusSystem.unit_grants_received_spillthrough(api, int(primary_target_id))
	var allowed := supports and ids_ok and lethal and overflow > 0 and next_alive and (attack_enabled or target_enabled)
	if lethal or overflow > 0 or int(next_target_id) > 0:
		print(
			"[SPILLTHROUGH] gate attacker=%d primary=%d next=%d targeting=%d targets=%s lethal=%s overflow=%d next_alive=%s attack_enabled=%s target_enabled=%s allowed=%s" % [
				int(ctx.attacker_id),
				int(primary_target_id),
				int(next_target_id),
				int(targeting),
				target_ids,
				str(lethal),
				int(overflow),
				str(next_alive),
				str(attack_enabled),
				str(target_enabled),
				str(allowed),
			]
		)
	return allowed


func has_runtime_initialized() -> bool:
	return turn_engine != null


func is_player(combat_id: int) -> bool:
	if turn_flow_query_host == null:
		return false
	return turn_flow_query_host.is_player(combat_id)


func is_in_strike_resolution() -> bool:
	return _strike_resolution_depth > 0


func get_active_delayed_reaction() -> DelayedReaction:
	return _active_delayed_reaction


func enqueue_delayed_reaction(reaction: DelayedReaction) -> void:
	if reaction == null:
		return

	var timing := int(reaction.timing)
	var bucket: Array = _delayed_reactions_by_timing.get(timing, [])
	bucket.append(reaction)
	_delayed_reactions_by_timing[timing] = bucket


func drain_delayed_reactions(timing: int) -> void:
	var timing_key := int(timing)
	if bool(_active_delayed_reaction_drains.get(timing_key, false)):
		return

	_active_delayed_reaction_drains[timing_key] = true

	while true:
		var bucket: Array = _delayed_reactions_by_timing.get(timing_key, [])
		if bucket.is_empty():
			_delayed_reactions_by_timing.erase(timing_key)
			break

		_delayed_reactions_by_timing[timing_key] = []
		for reaction_value in bucket:
			var reaction: DelayedReaction = reaction_value as DelayedReaction
			if reaction != null:
				_active_delayed_reaction = reaction
				reaction.execute(self)
				_active_delayed_reaction = null

	_active_delayed_reaction_drains.erase(timing_key)


# ============================================================================
# Checkpoint boundaries
# ============================================================================

func _apply_checkpoint_boundary(kind: int, allow_hooks := true) -> void:
	if sim == null or sim.checkpoint_processor == null:
		return

	var cp := sim.checkpoint_processor
	cp.flush_planning(kind, sim, allow_hooks)

	if cp.consume_dirty_turn_order():
		var engine := _engine()
		if engine != null:
			engine.mark_queue_dirty()
			_publish_turn_status()


# ============================================================================
# Public runtime-facing API
# ============================================================================

func begin_group_turn_flow(group_index: int, start_at_player := false, pre_player_friendly := false) -> void:
	if !_can_run():
		return
	var api := _api()
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	if start_at_player:
		engine.reset_for_new_battle()

	engine.begin_group_turn_state(group_index, start_at_player, pre_player_friendly)
	handle_group_turn_started(group_index)
	_publish_turn_status()
	_drive_turn_flow_until_blocked()


func request_player_end() -> void:
	var api := _api()
	if api == null:
		return

	var writer := api.writer
	if writer != null:
		writer.emit_end_turn_pressed(api.get_player_id())


func confirm_player_end_ready() -> void:
	_ensure_runtime_initialized()

	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	if !engine.begin_player_end_transition():
		return

	var player_id := _player_id()
	_service_arcana(TurnEngineCore.ArcanaProc.END_OF_TURN)
	engine.complete_player_end()
	_complete_actor_turn(player_id)
	_drive_turn_flow_until_blocked()


func add_combatant_from_data(
	data: CombatantData,
	group_index: int,
	insert_index: int = -1,
	is_player := false,
	current_health_override := -1
) -> int:
	var api := _api()
	if api == null:
		return 0

	return api.spawn_from_data(data, group_index, insert_index, is_player, current_health_override)


func request_urgent_planning_flush() -> void:
	#print("sim_runtime.gd request_urgent_planning_flush()")
	if sim == null or sim.checkpoint_processor == null:
		return
	sim.checkpoint_processor.flush_planning(CheckpointProcessor.Kind.URGENT_STATUS_LEGALITY, sim)#request_followup_flush()

# ============================================================================
# API hooks (assigned from host)
# ============================================================================

func on_summoned(summoned_id: int, group_index: int) -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.notify_summon_added(int(summoned_id), int(group_index))
	_publish_turn_status()


func on_unit_removed(cid: int, _group_index: int, _reason: String) -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.notify_actor_removed(int(cid))
	_publish_turn_status()
	_drive_turn_flow_until_blocked()


# ============================================================================
# Turn / queue callbacks
# ============================================================================

func handle_group_turn_started(group_index: int) -> void:
	#print("sim_runtime.gd handle_group_turn_started() group_index: ", group_index)
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer != null:
		writer.set_turn_context(engine._turn_token, group_index, 0)
		_group_turn_scope_handle = writer.scope_begin(Scope.Kind.GROUP_TURN, "group=%d" % group_index, 0)
		writer.emit_group_turn_begin(group_index)

	if int(group_index) == int(SimBattleAPI.FRIENDLY):
		var mana_ctx := ManaContext.new()
		mana_ctx.source_id = int(api.get_player_id())
		mana_ctx.mode = ManaContext.Mode.REFRESH_FOR_GROUP_TURN
		mana_ctx.group_index = int(group_index)
		mana_ctx.reason = "group_turn_begin_refresh"
		mana_ctx.new_mana = int(api.state.resource.max_mana)
		api.set_mana(mana_ctx)
	
	SimStatusSystem.on_group_turn_begin(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_BEGIN, true)

	ActionLifecycleSystem.on_group_turn_begin(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_BEGIN, true)


func handle_group_turn_ended(group_index: int) -> void:
	var api := _api()
	if api == null:
		return

	SimStatusSystem.on_group_turn_end(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_END, true)

	ActionLifecycleSystem.on_group_turn_end(api, group_index)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_GROUP_TURN_END, true)

	var writer := api.writer
	if writer != null:
		writer.emit_group_turn_end(group_index)
		if _group_turn_scope_handle != null:
			writer.scope_end(_group_turn_scope_handle) # group_turn
			_group_turn_scope_handle = null

	_schedule_next_group_turn(group_index)


func _publish_turn_status() -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer == null:
		return

	var snapshot := engine.build_pending_actor_snapshot()
	if snapshot == null:
		return

	var active_id := int(snapshot.active_id)
	var pending_ids := snapshot.pending_ids

	writer.set_turn_context(
		engine._turn_token,
		engine.active_group_index,
		int(active_id)
	)
	writer.emit_turn_status(
		int(active_id),
		pending_ids,
		int(engine.active_group_index),
		int(api.get_player_id())
	)

func _service_actor_turn(cid: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or host == null:
		return
	if api.state == null or api.state.has_terminal_outcome():
		return
	var writer := api.writer
	if writer != null:
		writer.set_turn_context(engine._turn_token, engine.active_group_index, cid)
		_actor_turn_scope_handle = writer.scope_begin(Scope.Kind.ACTOR_TURN, "actor=%d" % cid, cid)
		writer.emit_actor_begin(cid)

	if is_player(cid):
		if writer != null:
			writer.emit_player_input_reached(int(cid))
		return

	SimStatusSystem.on_actor_turn_begin(api, cid)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	run_npc_turn(cid)
	_complete_actor_turn(cid)


func _service_player_begin() -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or turn_flow_query_host == null:
		return

	var player_id := _player_id()
	if player_id > 0:
		SimStatusSystem.on_player_turn_begin(api, player_id)
		_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

		SimStatusSystem.on_actor_turn_begin(api, player_id)
		_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	engine.complete_player_begin()


func _service_arcana(proc: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	run_arcana_proc(proc)
	engine.complete_arcana()


# ============================================================================
# Internal flow helpers
# ============================================================================

func _schedule_next_group_turn(group_index: int) -> void:
	var api := _api()
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	
	var engine := _engine()
	if engine == null:
		return

	if group_index == 0:
		var finished_pre_player_friendly := bool(engine.ended_pre_player_friendly)

		if !finished_pre_player_friendly:
			begin_group_turn_flow(1, false)
		else:
			begin_group_turn_flow(0, false, false)
		return

	begin_group_turn_flow(0, false, true)


func _complete_actor_turn(cid: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var u: CombatantState = api.state.get_unit(int(cid)) if api.state != null else null
	if u != null and u.combatant_data != null and u.combatant_data.ai != null and u.ai_state != null:
		var ctx := ActionPlanner.make_context(api, u)
		ctx.runtime = self
		ActionLifecycleSystem.on_action_execution_completed(ctx)

	var writer := api.writer
	if writer != null:
		writer.emit_actor_end(cid)
		if _actor_turn_scope_handle != null:
			writer.scope_end(_actor_turn_scope_handle) # actor_turn
			_actor_turn_scope_handle = null

	SimStatusSystem.on_actor_turn_end(api, cid)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	_replan_actor_intent_after_turn_cleanup(cid)

	engine.complete_actor(cid)


func _drive_turn_flow_until_blocked() -> void:
	var engine := _engine()
	if engine == null:
		return

	while true:
		var directive := engine.advance()
		if directive == null:
			return

		match directive.kind:
			TurnFlowDirective.Kind.IDLE, TurnFlowDirective.Kind.BLOCKED:
				return
			TurnFlowDirective.Kind.REQUEST_PLAYER_BEGIN:
				_service_player_begin()
			TurnFlowDirective.Kind.REQUEST_ARCANA:
				_service_arcana(int(directive.arcana_proc))
			TurnFlowDirective.Kind.REQUEST_ACTOR:
				_publish_turn_status()
				_service_actor_turn(int(directive.actor_id))
				if is_player(int(directive.actor_id)):
					return
			TurnFlowDirective.Kind.GROUP_TURN_ENDED:
				handle_group_turn_ended(int(directive.group_index))
				return

func debug_kill_all_enemies() -> void:
	var api := _api()
	if api == null:
		return

	api.debug_kill_all_enemies()
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_CARD, true)


# ============================================================================
# Composite Execution
# ============================================================================

func run_npc_turn(cid: int) -> void:
	var api := _api()
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	if cid <= 0 or !api.is_alive(cid):
		return

	var u: CombatantState = api.state.get_unit(int(cid))
	if u == null or u.combatant_data == null:
		return

	var profile: NPCAIProfile = u.combatant_data.ai
	if profile == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	var ctx := ActionPlanner.make_context(api, u)
	ctx.runtime = self

	if !bool(ctx.state.get(Keys.FIRST_INTENTS_READY, false)):
		ctx.state[Keys.FIRST_INTENTS_READY] = true

	ActionPlanner.ensure_valid_plan_sim(profile, ctx, true)

	if int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) < 0:
		ActionPlanner.plan_next_intent_sim(profile, ctx, true)

	var idx := int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var action := ActionPlanner.get_action_by_idx(profile, idx)
	if action == null:
		push_warning("SimRuntime.run_npc_turn: no action selected for cid=%d planned_idx=%d action_count=%d" % [
			int(cid),
			idx,
			profile.actions.size()
		])
		_finish_npc_turn(ctx)
		return

	ctx.state[Keys.IS_ACTING] = true
	ActionLifecycleSystem.on_action_execution_started(ctx)
	ctx.state[Keys.ACTIONS_PERFORMED_COUNT] = int(
		ctx.state.get(Keys.ACTIONS_PERFORMED_COUNT, 0)
	) + 1

	for sm: StateModel in action.state_models:
		if sm != null:
			sm.change_state_sim(ctx)

	for pkg: NPCEffectPackage in action.effect_packages:
		if pkg == null:
			continue

		ctx.params.clear()

		for sm2: StateModel in pkg.state_models:
			if sm2 != null:
				sm2.change_state_sim(ctx)

		for pm: ParamModel in pkg.param_models:
			if pm != null:
				pm.change_params_sim(ctx)

		var effect_has_execute := pkg.effect != null and pkg.effect.has_method("execute")

		if effect_has_execute:
			pkg.effect.execute(ctx)

	_update_action_spree_state(profile, ctx.state, idx)


func run_attack(ctx: AttackContext) -> bool:
	var api := _api()
	if api == null or ctx == null:
		return false
	if ctx.api != null:
		api = ctx.api
	var allow_dead_source := bool(ctx.allow_dead_source)
	if int(ctx.attacker_id) <= 0:
		return false
	if !allow_dead_source and !api.is_alive(int(ctx.attacker_id)):
		return false

	var params: Dictionary = ctx.params if ctx.params else {}
	var strikes := maxi(int(ctx.strikes), 1)
	var mode := int(ctx.attack_mode)
	var targeting := int(ctx.targeting)
	var attacker_id := int(ctx.attacker_id)
	var source_id := int(ctx.source_id if ctx.source_id > 0 else attacker_id)
	var targeting_ctx := ctx.targeting_ctx
	if targeting_ctx == null:
		targeting_ctx = TargetingContext.new()
		ctx.targeting_ctx = targeting_ctx
	targeting_ctx.api = api
	targeting_ctx.source_id = source_id
	targeting_ctx.allow_dead_source = allow_dead_source
	targeting_ctx.target_type = targeting
	targeting_ctx.attack_mode = mode
	targeting_ctx.params = params
	var any := false

	var attack_scope := _begin_scope(Scope.Kind.ATTACK, "attacker=%d" % attacker_id, attacker_id, {
		Keys.ACTOR_ID: attacker_id,
		Keys.ATTACK_MODE: mode,
		Keys.STRIKES: strikes,
		Keys.TARGET_TYPE: targeting,
	})
	if attack_scope == null:
		return false

	for s in range(strikes):
		if !allow_dead_source and !api.is_alive(attacker_id):
			break

		var strike_scope := _begin_scope(Scope.Kind.STRIKE, "i=%d" % s, attacker_id, {
			Keys.STRIKE_INDEX: s,
			Keys.ATTACK_MODE: mode,
			Keys.TARGET_TYPE: targeting,
		})
		if strike_scope == null:
			_end_scope(attack_scope)
			return false

		var target_ids: Array[int] = AttackTargeting.get_target_ids(targeting_ctx)
		target_ids = target_ids.filter(func(id):
			return int(id) > 0 and api.is_alive(int(id))
		)
		ctx.current_strike_index = s
		ctx.current_primary_target_ids = target_ids.duplicate()
		ctx.current_spillthrough_target_id = 0
		ctx.current_spillthrough_damage = 0

		if target_ids.is_empty():
			_end_scope(strike_scope)
			continue

		var writer := _writer()
		if writer != null:
			writer.emit_strike(
				attacker_id,
				target_ids,
				mode,
				targeting,
				s,
				strikes,
				String(ctx.projectile_scene if !ctx.projectile_scene.is_empty() else params.get(Keys.PROJECTILE_SCENE, ""))
			)

		var dmg := _resolve_attack_damage(ctx)
		var banish_dmg := _resolve_attack_banish_damage(ctx)
		var deal_mod := int(ctx.deal_modifier_type)
		var take_mod := int(ctx.take_modifier_type)
		_strike_resolution_depth += 1
		var pending_spillthrough := {}

		for tid: int in target_ids:
			var spill_target_id := 0
			if _supports_single_target_spillthrough(targeting, target_ids):
				spill_target_id = int(AttackTargeting.get_next_target_id_after(targeting_ctx, int(tid)))

			var hit_scope := _begin_scope(Scope.Kind.HIT, "t=%d" % int(tid), attacker_id, {
				Keys.TARGET_ID: int(tid),
				Keys.STRIKE_INDEX: s,
				Keys.ATTACK_MODE: mode,
			})
			if hit_scope == null:
				_strike_resolution_depth = maxi(_strike_resolution_depth - 1, 0)
				drain_delayed_reactions(DelayedReaction.Timing.AFTER_STRIKE)
				_end_scope(strike_scope)
				_end_scope(attack_scope)
				return false

			var d := DamageContext.new()
			d.source_id = source_id
			d.target_id = int(tid)
			d.base_amount = dmg
			d.base_banish_amount = banish_dmg
			d.deal_modifier_type = deal_mod
			d.take_modifier_type = take_mod
			d.params = params
			d.tags = ctx.tags.duplicate()
			d.reason = ctx.reason
			d.origin_card_uid = ctx.origin_card_uid
			d.origin_arcanum_id = ctx.origin_arcanum_id
			api.resolve_damage_immediate(d)
			any = true
			if !_packed_has_int(ctx.affected_target_ids, int(tid)):
				ctx.affected_target_ids.append(int(tid))

			_end_scope(hit_scope)

			if !_should_apply_spillthrough(api, ctx, targeting, target_ids, int(tid), spill_target_id, d):
				continue
			pending_spillthrough = {
				"primary_target_id": int(tid),
				"spill_target_id": int(spill_target_id),
				"overflow_amount": int(d.overflow_amount),
				"overflow_banish_amount": int(d.overflow_banish_amount),
			}
			print(
				"[SPILLTHROUGH] queued strike=%d attacker=%d primary=%d spill=%d overflow=%d" % [
					int(s),
					int(attacker_id),
					int(tid),
					int(spill_target_id),
					int(d.overflow_amount),
				]
			)

		_end_scope(strike_scope)

		if !pending_spillthrough.is_empty():
			var spill_target_id := int(pending_spillthrough.get("spill_target_id", 0))
			var primary_target_id := int(pending_spillthrough.get("primary_target_id", 0))
			var overflow_amount := int(pending_spillthrough.get("overflow_amount", 0))
			var overflow_banish_amount := int(pending_spillthrough.get("overflow_banish_amount", 0))
			var spill_extra := {
				Keys.SPILLTHROUGH: true,
				Keys.CHAINED_FROM_PREVIOUS: true,
				Keys.ORIGIN_STRIKE_INDEX: int(s),
				Keys.CHAIN_SOURCE_TARGET_ID: int(primary_target_id),
				Keys.SPILLTHROUGH_DAMAGE: int(overflow_amount),
			}
			var spill_scope := _begin_scope(Scope.Kind.STRIKE, "spill=%d" % int(s), attacker_id, {
				Keys.STRIKE_INDEX: int(s),
				Keys.ATTACK_MODE: mode,
				Keys.TARGET_TYPE: targeting,
				Keys.SPILLTHROUGH: true,
				Keys.CHAINED_FROM_PREVIOUS: true,
				Keys.ORIGIN_STRIKE_INDEX: int(s),
				Keys.CHAIN_SOURCE_TARGET_ID: int(primary_target_id),
				Keys.SPILLTHROUGH_DAMAGE: int(overflow_amount),
			})
			if spill_scope == null:
				_strike_resolution_depth = maxi(_strike_resolution_depth - 1, 0)
				drain_delayed_reactions(DelayedReaction.Timing.AFTER_STRIKE)
				_end_scope(attack_scope)
				return false

			if writer != null:
				writer.emit_strike(
					attacker_id,
					[int(spill_target_id)],
					mode,
					targeting,
					s,
					strikes,
					String(ctx.projectile_scene if !ctx.projectile_scene.is_empty() else params.get(Keys.PROJECTILE_SCENE, "")),
					spill_extra
				)

			var spill_hit_scope := _begin_scope(Scope.Kind.HIT, "t=%d" % int(spill_target_id), attacker_id, {
				Keys.TARGET_ID: int(spill_target_id),
				Keys.STRIKE_INDEX: int(s),
				Keys.ATTACK_MODE: mode,
				Keys.SPILLTHROUGH: true,
				Keys.CHAINED_FROM_PREVIOUS: true,
				Keys.ORIGIN_STRIKE_INDEX: int(s),
				Keys.CHAIN_SOURCE_TARGET_ID: int(primary_target_id),
				Keys.SPILLTHROUGH_DAMAGE: int(overflow_amount),
			})
			if spill_hit_scope == null:
				_end_scope(spill_scope)
				_strike_resolution_depth = maxi(_strike_resolution_depth - 1, 0)
				drain_delayed_reactions(DelayedReaction.Timing.AFTER_STRIKE)
				_end_scope(attack_scope)
				return false

			ctx.current_spillthrough_target_id = int(spill_target_id)
			ctx.current_spillthrough_damage = int(overflow_amount)

			var spill_damage := DamageContext.new()
			spill_damage.source_id = source_id
			spill_damage.target_id = int(spill_target_id)
			spill_damage.base_amount = maxi(int(overflow_amount) - int(overflow_banish_amount), 0)
			spill_damage.base_banish_amount = int(overflow_banish_amount)
			spill_damage.deal_modifier_type = deal_mod
			spill_damage.take_modifier_type = take_mod
			spill_damage.params = params
			spill_damage.tags = ctx.tags.duplicate()
			spill_damage.reason = ctx.reason
			spill_damage.origin_card_uid = ctx.origin_card_uid
			spill_damage.origin_arcanum_id = ctx.origin_arcanum_id
			api.resolve_damage_immediate(spill_damage)
			any = true
			if !_packed_has_int(ctx.affected_target_ids, int(spill_target_id)):
				ctx.affected_target_ids.append(int(spill_target_id))

			_end_scope(spill_hit_scope)
			_end_scope(spill_scope)

		_strike_resolution_depth = maxi(_strike_resolution_depth - 1, 0)
		drain_delayed_reactions(DelayedReaction.Timing.AFTER_STRIKE)

	_end_scope(attack_scope)
	ctx.any_hit = any
	ctx.current_strike_index = -1
	ctx.current_primary_target_ids.clear()
	ctx.current_spillthrough_target_id = 0
	ctx.current_spillthrough_damage = 0
	return any


func run_status_action(ctx: StatusContext) -> void:
	var api := _api()
	if api == null or api.state == null or ctx == null:
		return

	var actor_id := int(ctx.actor_id if ctx.actor_id > 0 else ctx.source_id)
	var source_id := int(ctx.source_id if ctx.source_id > 0 else actor_id)
	if int(ctx.target_id) <= 0 or ctx.status_id == &"":
		return

	var status_scope := _begin_scope(
		Scope.Kind.STATUS_ACTION,
		"id=%s tgt=%d" % [String(ctx.status_id), int(ctx.target_id)],
		actor_id,
		{
			Keys.ACTOR_ID: int(actor_id),
			Keys.SOURCE_ID: int(source_id),
			Keys.TARGET_ID: int(ctx.target_id),
			Keys.STATUS_ID: ctx.status_id,
			Keys.STATUS_PENDING: bool(ctx.pending),
			Keys.INTENSITY: int(ctx.intensity),
			Keys.DURATION: int(ctx.duration),
		}
	)
	if status_scope == null:
		return

	ctx.actor_id = actor_id
	ctx.source_id = source_id
	api.apply_status(ctx)

	_end_scope(status_scope)

func run_realize_pending_statuses(actor_id: int, source_id: int = 0, reason: String = "") -> void:
	var api := _api()
	if api == null or api.state == null or actor_id <= 0 or !api.is_alive(actor_id):
		return

	var src_id := int(source_id if source_id > 0 else actor_id)
	var status_scope := _begin_scope(
		Scope.Kind.STATUS_ACTION,
		"realize_pending tgt=%d" % int(actor_id),
		actor_id,
		{
			Keys.ACTOR_ID: int(actor_id),
			Keys.SOURCE_ID: int(src_id),
			Keys.TARGET_ID: int(actor_id),
			Keys.REASON: String(reason),
		}
	)
	if status_scope == null:
		return

	api.realize_pending_statuses(int(actor_id), int(src_id), reason)
	_end_scope(status_scope)


func run_summon_action(ctx: SummonContext) -> void:
	var api := _api()
	if api == null or api.state == null or ctx == null:
		return

	var actor_id := int(ctx.actor_id if ctx.actor_id > 0 else ctx.source_id)
	if actor_id <= 0:
		return

	var source_id := int(ctx.source_id if ctx.source_id > 0 else actor_id)
	var group_index := clampi(int(ctx.group_index), 0, 1)
	if ctx.summon_data == null:
		push_warning("SimRuntime.run_summon_action(): missing summon_data")
		return
	ctx.actor_id = actor_id
	ctx.source_id = source_id

	var summon_scope := _begin_scope(
		Scope.Kind.SUMMON_ACTION,
		"count=1 g=%d idx=%d" % [group_index, int(ctx.insert_index)],
		actor_id,
		{
			Keys.ACTOR_ID: int(actor_id),
			Keys.SOURCE_ID: int(source_id),
			Keys.GROUP_INDEX: int(group_index),
			Keys.INSERT_INDEX: int(ctx.insert_index),
			Keys.SUMMON_COUNT: 1,
			Keys.PROTO: String(ctx.summon_data.resource_path),
		}
	)
	if summon_scope == null:
		return

	api.summon(ctx)

	_end_scope(summon_scope)


func run_move(ctx: MoveContext) -> void:
	var api := _api()
	if api == null or api.state == null or ctx == null or int(ctx.actor_id) <= 0:
		return

	var u := api.state.get_unit(int(ctx.actor_id))
	if u == null or !u.is_alive():
		return

	var extra := {}
	if int(ctx.target_id) > 0:
		extra[Keys.TARGET_ID] = int(ctx.target_id)
	if int(ctx.index) >= 0:
		extra[Keys.TO_INDEX] = int(ctx.index)

	var move_scope := _begin_scope(Scope.Kind.MOVE, "actor=%d" % int(ctx.actor_id), int(ctx.actor_id), extra)
	if move_scope == null:
		return
	api.resolve_move(ctx)
	var engine := _engine()
	if engine != null:
		engine.notify_move_executed(ctx)
	_publish_turn_status()
	_end_scope(move_scope)


func run_fade(ctx: FadeContext) -> void:
	var api := _api()
	if api == null or api.state == null or ctx == null or int(ctx.actor_id) <= 0:
		return

	var u: CombatantState = api.state.get_unit(int(ctx.actor_id))
	if u == null or !u.alive:
		return

	var fade_scope := _begin_scope(Scope.Kind.FADE, "fade_unit", int(ctx.actor_id))
	if fade_scope == null:
		return
	api.fade_unit(ctx)
	_end_scope(fade_scope)


func run_arcana_proc(proc: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or sim == null or sim.state == null:
		return
	if host == null or host.arcana_catalog == null:
		push_warning("SimRuntime: no arcana_catalog; cannot run arcana")
		return

	var arcana_scope := _begin_scope(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
	if arcana_scope == null:
		return
	var writer := _writer()
	if writer != null:
		writer.emit_arcana_proc(proc)

	var arcanum_type := _proc_to_arcanum_type(proc)
	if arcanum_type >= 0:
		for entry: ArcanaState.ArcanumEntry in sim.state.arcana.list:
			if entry == null or int(entry.type) != arcanum_type:
				continue

			var id := entry.id
			if id == &"":
				continue

			var proto: Arcanum = host.arcana_catalog.get_proto(id)
			if proto == null:
				push_warning("SimRuntime: missing proto for id=%s" % String(id))
				continue

			var player_id := int(sim.state.groups[0].player_id)
			var arcanum_scope := _begin_scope(Scope.Kind.ARCANUM, "id=%s" % String(id), player_id)
			if arcanum_scope == null:
				_end_scope(arcana_scope)
				return

			if writer != null:
				writer.emit_arcanum_proc(player_id, id, proc)
			_dispatch_battle_timed_arcanum(proto, int(proc), sim.api)

			_end_scope(arcanum_scope)

	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ARCANA, true)
	_end_scope(arcana_scope)

func _dispatch_battle_timed_arcanum(proto: Arcanum, proc: int, api: SimBattleAPI) -> void:
	if proto == null or api == null:
		return

	match int(proc):
		TurnEngineCore.ArcanaProc.START_OF_COMBAT:
			proto.on_battle_started(api)
		TurnEngineCore.ArcanaProc.START_OF_TURN:
			proto.on_turn_started(api)
		TurnEngineCore.ArcanaProc.END_OF_TURN:
			proto.on_turn_ended(api)


func apply_attack_now(spec: SimAttackSpec) -> bool:
	var api := _api()
	if api == null or api.state == null or spec == null:
		return false
	if int(spec.attacker_id) <= 0:
		return false
	if !bool(spec.allow_dead_source) and !api.is_alive(int(spec.attacker_id)):
		return false

	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = api
	ai_ctx.runtime = self
	ai_ctx.cid = int(spec.attacker_id)
	ai_ctx.combatant_state = api.state.get_unit(int(spec.attacker_id))
	ai_ctx.combatant_data = ai_ctx.combatant_state.combatant_data if ai_ctx.combatant_state != null else null
	ai_ctx.rng = ai_ctx.combatant_state.rng if ai_ctx.combatant_state != null else null
	ai_ctx.state = {}
	ai_ctx.params = spec.params.duplicate(true) if spec.params != null else {}
	ai_ctx.forecast = false

	ai_ctx.params[Keys.STRIKES] = maxi(int(spec.strikes), 1)
	ai_ctx.params[Keys.DEAL_MOD_TYPE] = int(spec.deal_modifier_type)
	ai_ctx.params[Keys.TAKE_MOD_TYPE] = int(spec.take_modifier_type)
	if int(spec.base_damage) > 0:
		ai_ctx.params[Keys.DAMAGE] = int(spec.base_damage)
		ai_ctx.params[Keys.DAMAGE_MELEE] = int(spec.base_damage)
		ai_ctx.params[Keys.DAMAGE_RANGED] = int(spec.base_damage)
	if int(spec.base_banish_amount) > 0:
		ai_ctx.params[Keys.BANISH_DAMAGE] = int(spec.base_banish_amount)

	for m in spec.param_models:
		if m != null:
			m.change_params_sim(ai_ctx)

	var attack_ctx := AttackContext.new()
	attack_ctx.api = api
	attack_ctx.runtime = self
	attack_ctx.attacker_id = int(spec.attacker_id)
	attack_ctx.source_id = int(spec.attacker_id)
	attack_ctx.allow_dead_source = bool(spec.allow_dead_source)
	attack_ctx.strikes = maxi(int(spec.strikes), 1)
	attack_ctx.deal_modifier_type = int(spec.deal_modifier_type)
	attack_ctx.take_modifier_type = int(spec.take_modifier_type)
	attack_ctx.params = ai_ctx.params
	attack_ctx.attack_mode = int(attack_ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	attack_ctx.targeting = int(attack_ctx.params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	attack_ctx.projectile_scene = String(attack_ctx.params.get(Keys.PROJECTILE_SCENE, ""))
	attack_ctx.reason = "attack_now"
	attack_ctx.tags = spec.tags.duplicate()
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = api
	attack_ctx.targeting_ctx.source_id = int(spec.attacker_id)
	attack_ctx.targeting_ctx.allow_dead_source = bool(spec.allow_dead_source)
	attack_ctx.targeting_ctx.target_type = int(attack_ctx.targeting)
	attack_ctx.targeting_ctx.attack_mode = int(attack_ctx.attack_mode)
	attack_ctx.targeting_ctx.params = attack_ctx.params
	attack_ctx.targeting_ctx.explicit_target_ids = spec.explicit_target_ids.duplicate()
	if int(spec.base_damage) > 0:
		attack_ctx.base_damage = int(spec.base_damage)
		attack_ctx.base_damage_melee = int(spec.base_damage)
		attack_ctx.base_damage_ranged = int(spec.base_damage)
	attack_ctx.base_banish_amount = maxi(int(spec.base_banish_amount), 0)

	return run_attack(attack_ctx)


func _begin_scope(kind: int, label: String, actor_id: int = 0, extra := {}) -> ScopeHandle:
	var writer := _writer()
	if writer == null:
		return null
	return writer.scope_begin(kind, label, actor_id, extra)


func _end_scope(handle: ScopeHandle) -> int:
	var writer := _writer()
	if writer == null or handle == null:
		return 0
	return writer.scope_end(handle)


func _finish_npc_turn(ctx: NPCAIContext) -> void:
	if ctx == null or ctx.state == null:
		return

	ctx.state[Keys.IS_ACTING] = false


func _replan_actor_intent_after_turn_cleanup(cid: int) -> void:
	var api := _api()
	if api == null or api.state == null or api.state.has_terminal_outcome():
		return
	if cid <= 0:
		return

	var u: CombatantState = api.state.get_unit(int(cid))
	if u == null or !u.is_alive():
		return
	if u.combatant_data == null or u.combatant_data.ai == null:
		return

	ActionPlanner.ensure_ai_state_initialized(u)

	var profile: NPCAIProfile = u.combatant_data.ai
	var ctx := ActionPlanner.make_context(api, u)
	ctx.runtime = self

	# Finishing an action starts a fresh intent cycle for the actor.
	ctx.state[ActionPlanner.KEY_PLANNED_IDX] = -1
	ctx.state[Keys.PLANNED_SELECTION_SOURCE] = ActionPlanner.SELECTION_SOURCE_NONE
	ctx.state[ActionPlanner.STABILITY_BROKEN] = false
	ctx.state[Keys.IS_ACTING] = false
	ctx.state[Keys.FIRST_INTENTS_READY] = true

	ActionPlanner.plan_next_intent_sim(profile, ctx, true)
	ActionIntentPresenter.emit_current_intent(api, int(cid))


func _update_action_spree_state(profile: NPCAIProfile, state: Dictionary, executed_idx: int) -> void:
	if profile == null or state == null:
		return

	for i in range(profile.actions.size()):
		var action_state := ActionPlanner.ensure_action_state_sim(state, i)
		if i == executed_idx:
			action_state[Keys.SPREE] = int(action_state.get(Keys.SPREE, 0)) + 1
		else:
			action_state[Keys.SPREE] = 0


func _resolve_attack_damage(ctx: AttackContext) -> int:
	if ctx == null:
		return 0
	var params: Dictionary = ctx.params if ctx.params else {}
	var mode := int(ctx.attack_mode)
	var dmg := 0
	if mode == int(Attack.Mode.RANGED) and int(ctx.base_damage_ranged) > 0:
		dmg = int(ctx.base_damage_ranged)
	elif mode != int(Attack.Mode.RANGED) and int(ctx.base_damage_melee) > 0:
		dmg = int(ctx.base_damage_melee)
	elif int(ctx.base_damage) > 0:
		dmg = int(ctx.base_damage)
	elif params.has(Keys.DAMAGE_MELEE) or params.has(Keys.DAMAGE_RANGED):
		var k := Keys.DAMAGE_RANGED if mode == Attack.Mode.RANGED else Keys.DAMAGE_MELEE
		dmg = int(params.get(k, 0))
	else:
		dmg = int(params.get(Keys.DAMAGE, 0))
	return maxi(dmg, 0)


func _resolve_attack_banish_damage(ctx: AttackContext) -> int:
	if ctx == null:
		return 0
	var params: Dictionary = ctx.params if ctx.params else {}
	if int(ctx.base_banish_amount) > 0:
		return int(ctx.base_banish_amount)
	return maxi(int(params.get(Keys.BANISH_DAMAGE, 0)), 0)


func _resolve_summon_data(value) -> CombatantData:
	if value == null:
		return null
	if value is CombatantData:
		return value
	if value is String:
		var path := String(value)
		if path.is_empty():
			return null
		var res := load(path)
		return res if res is CombatantData else null
	return null


func _proc_to_arcanum_type(proc: int) -> int:
	match proc:
		TurnEngineCore.ArcanaProc.START_OF_COMBAT:
			return int(Arcanum.Type.START_OF_COMBAT)
		TurnEngineCore.ArcanaProc.START_OF_TURN:
			return int(Arcanum.Type.START_OF_TURN)
		TurnEngineCore.ArcanaProc.END_OF_TURN:
			return int(Arcanum.Type.END_OF_TURN)
		_:
			return -1


# ============================================================================
# Card Execution
# ============================================================================

func begin_card_execution(ctx: CardContext) -> bool:
	if ctx == null or ctx.finished:
		return false
	if ctx.card_data == null:
		return false

	ctx.action_states.clear()
	ctx.next_action_index = 0
	ctx.current_action_index = -1
	ctx.activation_committed_to_view = false
	ctx.canceled = false
	ctx.finished = false
	ctx.card_scope_handle = null
	ctx.card_scope_opened = false
	ctx.card_play_committed = false
	ctx.waiting_async_action_index = -1
	ctx.waiting_async_request_id = 0
	ctx.interaction_payloads.clear()

	var actions: Array = ctx.card_data.actions
	for i in range(actions.size()):
		var action := actions[i] as CardAction
		if action == null:
			continue

		var st := CardActionExecutionState.new()
		st.action_index = i
		st.action = action
		st.interaction_mode = action.get_interaction_mode(ctx)
		st.state = CardActionExecutionState.State.PENDING
		ctx.action_states.append(st)

	return continue_card_execution(ctx)

#func begin_card_execution(ctx: CardContext) -> bool:
	#if ctx == null:
		#return false
#
	#initialize_card_context(ctx)
	#return continue_card_execution(ctx)

func continue_card_execution(ctx: CardContext) -> bool:
	if ctx == null or ctx.finished:
		return false
	if ctx.canceled:
		_finalize_card_execution(ctx)
		return false

	while ctx.next_action_index < ctx.action_states.size():
		var st: CardActionExecutionState = ctx.action_states[ctx.next_action_index]
		if st == null or st.action == null:
			ctx.next_action_index += 1
			continue

		ctx.current_action_index = st.action_index

		match int(st.state):
			CardActionExecutionState.State.EXECUTED, \
			CardActionExecutionState.State.SKIPPED:
				ctx.next_action_index += 1
				continue

			CardActionExecutionState.State.WAITING_INTERACTION, \
			CardActionExecutionState.State.WAITING_ASYNC_RESOLUTION:
				return true

			CardActionExecutionState.State.COVERED, \
			CardActionExecutionState.State.PENDING:
				if int(st.state) == int(CardActionExecutionState.State.PENDING) \
				and int(st.interaction_mode) != int(CardAction.InteractionMode.NONE):
					st.state = CardActionExecutionState.State.WAITING_INTERACTION
					if !st.action.activate_interaction(ctx):
						st.state = CardActionExecutionState.State.CANCELED
						ctx.canceled = true
						_finalize_card_execution(ctx)
						return false
					return true

				if !_commit_card_play_if_needed(ctx):
					ctx.canceled = true
					_finalize_card_execution(ctx)
					return false

				if !execute_card_action(ctx, st.action_index):
					st.state = CardActionExecutionState.State.CANCELED
					ctx.canceled = true
					_finalize_card_execution(ctx)
					return false

				if st.action.waits_for_async_resolution_after_activate_sim(ctx):
					ctx.waiting_async_action_index = st.action_index
					st.state = CardActionExecutionState.State.WAITING_ASYNC_RESOLUTION
					return true

				st.state = CardActionExecutionState.State.EXECUTED
				ctx.next_action_index += 1
				continue

			CardActionExecutionState.State.CANCELED:
				ctx.canceled = true
				_finalize_card_execution(ctx)
				return false

	ctx.finished = true
	_finalize_card_execution(ctx)
	return true

func execute_card_action(ctx: CardContext, action_index: int) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null or st.action == null:
		return false

	ctx.current_action_index = action_index
	return st.action.activate_sim(ctx)

func cover_waiting_action_and_continue(
	ctx: CardContext,
	action_index: int,
	payload: Dictionary = {}
) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null or st.action == null:
		return false
	if int(st.state) != int(CardActionExecutionState.State.WAITING_INTERACTION):
		return false

	if !payload.is_empty():
		ctx.interaction_payloads[action_index] = payload.duplicate(true)

	st.state = CardActionExecutionState.State.COVERED
	ctx.current_action_index = action_index

	# Execute the just-covered action now.
	if !_commit_card_play_if_needed(ctx):
		st.state = CardActionExecutionState.State.CANCELED
		ctx.canceled = true
		_finalize_card_execution(ctx)
		return false

	if !execute_card_action(ctx, action_index):
		st.state = CardActionExecutionState.State.CANCELED
		ctx.canceled = true
		_finalize_card_execution(ctx)
		return false

	st.state = CardActionExecutionState.State.EXECUTED
	ctx.next_action_index = action_index + 1

	return continue_card_execution(ctx)

func resume_async_action(ctx: CardContext, action_index: int, payload: Dictionary = {}) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		push_warning("SimRuntime.resume_async_action(): invalid action_index=%d" % action_index)
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null:
		push_warning("SimRuntime.resume_async_action(): missing action state action_index=%d" % action_index)
		return false
	if int(st.state) != int(CardActionExecutionState.State.WAITING_ASYNC_RESOLUTION):
		push_warning("SimRuntime.resume_async_action(): action not waiting async action_index=%d state=%d" % [action_index, int(st.state)])
		return false
	if int(ctx.waiting_async_action_index) != int(action_index):
		push_warning("SimRuntime.resume_async_action(): mismatched waiting action expected=%d got=%d" % [int(ctx.waiting_async_action_index), action_index])
		return false

	if !payload.is_empty():
		var merged := get_action_interaction_payload(ctx, action_index)
		for key in payload.keys():
			merged[key] = payload[key]
		ctx.interaction_payloads[action_index] = merged

	st.state = CardActionExecutionState.State.EXECUTED
	ctx.waiting_async_action_index = -1
	ctx.waiting_async_request_id = 0
	ctx.current_action_index = action_index
	ctx.next_action_index = action_index + 1
	return continue_card_execution(ctx)

func cancel_waiting_action(ctx: CardContext, action_index: int) -> bool:
	if ctx == null:
		return false
	if action_index < 0 or action_index >= ctx.action_states.size():
		return false

	var st: CardActionExecutionState = ctx.action_states[action_index]
	if st == null:
		return false

	st.state = CardActionExecutionState.State.CANCELED
	ctx.canceled = true
	ctx.finished = true
	_finalize_card_execution(ctx, false)
	return false


func mark_action_skipped(ctx: CardContext, action_index: int) -> void:
	if ctx == null:
		return
	if action_index < 0 or action_index >= ctx.action_states.size():
		return

	var state: CardActionExecutionState = ctx.action_states[action_index]
	if state == null:
		return

	state.state = CardActionExecutionState.State.SKIPPED


func append_affected_id(ctx: CardContext, cid: int) -> void:
	if ctx == null or cid <= 0:
		return
	if !_packed_has_int(ctx.affected_ids, cid):
		ctx.affected_ids.append(cid)


func append_summoned_id(ctx: CardContext, cid: int) -> void:
	if ctx == null or cid <= 0:
		return
	if !_packed_has_int(ctx.summoned_ids, cid):
		ctx.summoned_ids.append(cid)
	if !_packed_has_int(ctx.affected_ids, cid):
		ctx.affected_ids.append(cid)

func get_action_interaction_payload(ctx: CardContext, action_index: int) -> Dictionary:
	if ctx == null:
		return {}
	if !ctx.interaction_payloads.has(action_index):
		return {}
	var d = ctx.interaction_payloads[action_index]
	return d.duplicate(true) if d is Dictionary else {}

# ============================================================================
# Card Execution Helpers
# ============================================================================

func _ensure_card_scope_open(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.card_scope_opened:
		return true

	var label := "card"
	if ctx.card_data != null:
		label = "uid=%s %s" % [String(ctx.card_data.uid), String(ctx.card_data.name)]

	ctx.card_scope_handle = ctx.api.writer.scope_begin(
		Scope.Kind.CARD,
		label,
		int(ctx.source_id),
		{}
	)
	ctx.card_scope_opened = (ctx.card_scope_handle != null)
	return ctx.card_scope_opened

func _commit_card_play_if_needed(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.source_card == null or ctx.card_data == null:
		return false

	if ctx.card_play_committed:
		return true

	if !_ensure_card_scope_open(ctx):
		return false

	if !ctx.emitted_card_played:
		ctx.api.writer.emit_card_played_ctx(ctx)
		ctx.emitted_card_played = true

	if !ctx.mana_spent:
		var mana_ctx := ManaContext.new()
		mana_ctx.source_id = int(ctx.source_id)
		mana_ctx.reason = "card_spend"
		if !ctx.api.spend_mana_for_card(mana_ctx, ctx.card_data):
			return false
		ctx.mana_spent = true

	ctx.card_play_committed = true
	if !ctx.activation_committed_to_view and ctx.source_card != null and is_instance_valid(ctx.source_card):
		ctx.source_card.commit_activation()
		ctx.activation_committed_to_view = true
	return true

func _close_card_scope(ctx: CardContext) -> void:
	if ctx == null or ctx.api == null:
		return
	if !ctx.card_scope_opened:
		return

	ctx.api.writer.scope_end(ctx.card_scope_handle)
	ctx.card_scope_opened = false
	ctx.card_scope_handle = null


func _finalize_card_execution(ctx: CardContext, committed := true) -> void:
	if ctx == null:
		return

	ctx.waiting_async_action_index = -1
	ctx.waiting_async_request_id = 0
	_close_card_scope(ctx)
	if ctx.source_card != null and is_instance_valid(ctx.source_card):
		ctx.source_card.finish_activation(committed)
	ctx.current_action_index = -1
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_CARD)


func _packed_has_int(arr: PackedInt32Array, value: int) -> bool:
	for x in arr:
		if int(x) == int(value):
			return true
	return false


func _ctx_card_name(ctx: CardContext) -> String:
	if ctx == null or ctx.card_data == null:
		return "<no card>"
	return String(ctx.card_data.name)
