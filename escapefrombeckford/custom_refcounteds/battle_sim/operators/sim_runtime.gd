# sim_runtime.gd

class_name SimRuntime extends RefCounted

# Runtime orchestration for a single Sim.
#
# Responsibilities:
# - own TurnEngineCore and TurnEngineHostSim for this Sim
# - bridge TurnEngineCore callbacks into SIM-side lifecycle work
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
var turn_engine_host_sim: TurnEngineHostSim


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
	turn_engine_host_sim = null

func _ensure_turn_engine_host_initialized() -> void:
	if host == null:
		return

	if turn_engine_host_sim == null:
		turn_engine_host_sim = TurnEngineHostSim.new(sim, host)
	else:
		turn_engine_host_sim.bind(sim, host)

func _connect_turn_engine_signals(engine: TurnEngineCore) -> void:
	if engine == null:
		return

	engine.group_turn_ended.connect(_on_group_turn_ended)
	engine.arcana_proc_requested.connect(_on_arcana_proc_requested)
	engine.actor_requested.connect(_on_actor_requested)
	engine.player_begin_requested.connect(_on_player_begin_requested)
	engine.player_end_requested.connect(_on_player_end_requested)
	engine.pending_view_changed.connect(_on_pending_view_changed)

func _ensure_runtime_initialized() -> void:
	_ensure_turn_engine_host_initialized()

	if turn_engine != null:
		return

	turn_engine = TurnEngineCore.new(turn_engine_host_sim)
	_connect_turn_engine_signals(turn_engine)

func clone_turn_flow_from(source_runtime: SimRuntime) -> bool:
	if source_runtime == null or source_runtime.turn_engine == null:
		return false

	_ensure_turn_engine_host_initialized()
	if turn_engine_host_sim == null:
		return false

	turn_engine = source_runtime.turn_engine.clone_for_host(turn_engine_host_sim)
	_connect_turn_engine_signals(turn_engine)
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
	if turn_engine_host_sim == null:
		return 0
	return turn_engine_host_sim.get_player_id()


func _can_run() -> bool:
	return sim != null and sim.api != null and host != null


func has_runtime_initialized() -> bool:
	return turn_engine != null


func is_player(combat_id: int) -> bool:
	if turn_engine_host_sim == null:
		return false
	return turn_engine_host_sim.is_player(combat_id)


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
			engine.request_queue_rebuild_and_publish()


# ============================================================================
# Public runtime-facing API
# ============================================================================

func start_group_turn(group_index: int, start_at_player := false, pre_player_friendly := false) -> void:
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

	handle_group_turn_started(group_index)
	engine.start_group_turn(group_index, start_at_player, pre_player_friendly)


func request_player_end() -> void:
	var api := _api()
	if api == null:
		return

	var writer := api.writer
	if writer != null:
		writer.emit_end_turn_pressed(api.get_player_id())


func notify_player_discard_animation_finished() -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.request_player_end()


func add_combatant_from_data(data: CombatantData, group_index: int, insert_index: int = -1, is_player := false) -> int:
	var api := _api()
	if api == null:
		return 0

	return api.spawn_from_data(data, group_index, insert_index, is_player)


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


func on_unit_removed(cid: int, _group_index: int, _reason: String) -> void:
	_ensure_runtime_initialized()

	var engine := _engine()
	if engine == null:
		return

	engine.notify_actor_removed(int(cid))


# ============================================================================
# TurnEngineCore signal handlers
# ============================================================================

func _on_group_turn_ended(group_index: int) -> void:
	handle_group_turn_ended(group_index)


func _on_arcana_proc_requested(proc: int, token: int) -> void:
	handle_arcana_proc_requested(proc, token)


func _on_actor_requested(cid: int) -> void:
	handle_actor_requested(cid)


func _on_player_begin_requested(token: int) -> void:
	handle_player_begin_requested(token)


func _on_player_end_requested(token: int) -> void:
	handle_player_end_requested(token)


func _on_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	handle_pending_view_changed(active_id, pending_ids)


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
		writer.scope_begin(Scope.Kind.GROUP_TURN, "group=%d" % group_index, 0)
		writer.emit_group_turn_begin(group_index)
		
	api.refresh_mana_for_group_turn(group_index)
	
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
		writer.scope_end() # group_turn

	_schedule_next_group_turn(group_index)


func handle_pending_view_changed(active_id: int, pending_ids: PackedInt32Array) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer == null:
		return

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


func handle_actor_requested(cid: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or host == null:
		return
	if api.state == null or api.state.has_terminal_outcome():
		return
	var writer := api.writer
	if writer != null:
		writer.set_turn_context(engine._turn_token, engine.active_group_index, cid)
		writer.scope_begin(Scope.Kind.ACTOR_TURN, "actor=%d" % cid, cid)
		writer.emit_actor_begin(cid)

	SimStatusSystem.on_actor_turn_begin(api, cid)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	if is_player(cid):
		if writer != null:
			writer.emit_player_input_reached(int(cid))
		return

	run_npc_turn(cid)

	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end() # actor_turn

	SimStatusSystem.on_actor_turn_end(api, cid)
	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	engine.notify_actor_done(cid)


func handle_player_begin_requested(token: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or turn_engine_host_sim == null:
		return

	var player_id := _player_id()
	if player_id > 0:
		SimStatusSystem.on_actor_turn_begin(api, player_id)
		_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

	engine.notify_player_begin_done(token)


func handle_player_end_requested(token: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or turn_engine_host_sim == null:
		return

	var player_id := _player_id()

	engine.request_end_of_turn_arcana(func():
		engine.notify_player_end_done(token)

		SimStatusSystem.on_actor_turn_end(api, player_id)
		_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ACTOR_TURN, true)

		_notify_actor_done(player_id)
	)


func handle_arcana_proc_requested(proc: int, token: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	run_arcana_proc(proc)

	engine.notify_arcana_proc_done(token)


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
			start_group_turn(1, false)
		else:
			start_group_turn(0, false, false)
		return

	start_group_turn(0, false, true)


func _notify_actor_done(cid: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null:
		return

	var writer := api.writer
	if writer != null:
		writer.emit_actor_end(cid)
		writer.scope_end() # actor_turn

	engine.notify_actor_done(cid)

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

	if !bool(ctx.state.get(ActionPlanner.FIRST_INTENTS_READY, false)):
		ctx.state[ActionPlanner.FIRST_INTENTS_READY] = true

	ActionPlanner.ensure_valid_plan_sim(profile, ctx, true)

	if int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1)) < 0:
		ActionPlanner.plan_next_intent_sim(profile, ctx, true)

	var idx := int(ctx.state.get(ActionPlanner.KEY_PLANNED_IDX, -1))
	var action := ActionPlanner.get_action_by_idx(profile, idx)
	if action == null:
		_finish_npc_turn(ctx)
		return

	ctx.state[ActionPlanner.IS_ACTING] = true
	ActionLifecycleSystem.on_action_execution_started(ctx)

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

		if pkg.effect != null and pkg.effect.has_method("execute_sim"):
			pkg.effect.execute_sim(ctx)

	ctx.state[ActionPlanner.KEY_PLANNED_IDX] = -1
	ctx.state[ActionPlanner.IS_ACTING] = false
	ctx.state[ActionPlanner.STABILITY_BROKEN] = false
	ctx.state[ActionPlanner.ACTIONS_TAKEN] = int(ctx.state.get(ActionPlanner.ACTIONS_TAKEN, 0)) + 1

	if _should_immediately_replan_intent(api, u):
		ActionPlanner.plan_next_intent_sim(profile, ctx, true)
	else:
		ActionIntentPresenter.emit_set_intent(api, profile, ctx, -1)


func run_attack(ctx: NPCAIContext) -> bool:
	var api := _api()
	if api == null or ctx == null:
		return false
	if ctx.cid <= 0 or !api.is_alive(ctx.cid):
		return false

	var params: Dictionary = ctx.params if ctx.params else {}
	var strikes := maxi(int(params.get(Keys.STRIKES, 1)), 1)
	var mode := int(params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	var targeting := int(params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	var any := false

	_begin_scope(Scope.Kind.ATTACK, "attacker=%d" % int(ctx.cid), int(ctx.cid), {
		Keys.ACTOR_ID: int(ctx.cid),
		Keys.ATTACK_MODE: mode,
		Keys.STRIKES: strikes,
		Keys.TARGET_TYPE: targeting,
	})

	for s in range(strikes):
		if !api.is_alive(ctx.cid):
			break

		_begin_scope(Scope.Kind.STRIKE, "i=%d" % s, int(ctx.cid), {
			Keys.STRIKE_INDEX: s,
			Keys.ATTACK_MODE: mode,
			Keys.TARGET_TYPE: targeting,
		})

		var target_ids: Array[int] = AttackTargeting.get_target_ids(api, ctx.cid, params)
		target_ids = target_ids.filter(func(id):
			return int(id) > 0 and api.is_alive(int(id))
		)

		if target_ids.is_empty():
			_end_scope()
			continue

		var writer := _writer()
		if writer != null:
			writer.emit_strike(
				int(ctx.cid),
				target_ids,
				mode,
				targeting,
				s,
				strikes,
				String(params.get(Keys.PROJECTILE_SCENE, ""))
			)

		var dmg := 0
		if params.has(Keys.DAMAGE_MELEE) or params.has(Keys.DAMAGE_RANGED):
			var k := Keys.DAMAGE_RANGED if mode == Attack.Mode.RANGED else Keys.DAMAGE_MELEE
			dmg = int(params.get(k, 0))
		else:
			dmg = int(params.get(Keys.DAMAGE, 0))
		dmg = maxi(dmg, 0)

		var deal_mod := int(params.get(Keys.DEAL_MOD_TYPE, Modifier.Type.DMG_DEALT))
		var take_mod := int(params.get(Keys.TAKE_MOD_TYPE, Modifier.Type.DMG_TAKEN))

		for tid: int in target_ids:
			_begin_scope(Scope.Kind.HIT, "t=%d" % int(tid), int(ctx.cid), {
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
			d.params = params
			api.resolve_damage_immediate(d)
			any = true

			_end_scope()

		_end_scope()

	_end_scope()
	return any


func run_status_action(ctx: NPCAIContext) -> void:
	var api := _api()
	if api == null or api.state == null or ctx == null or bool(ctx.forecast):
		return

	var params: Dictionary = ctx.params if ctx.params else {}

	var target_id := int(ParamModel._actor_id(ctx))
	if target_id <= 0:
		target_id = int(ctx.cid)
	if target_id <= 0:
		return

	var status_id: StringName = &""
	if params.has(Keys.STATUS_ID):
		var v = params[Keys.STATUS_ID]
		if v is StringName:
			status_id = v
		elif v is String:
			status_id = StringName(v)

	if status_id == &"":
		var status_res = params.get(Keys.STATUS_SCENE, null)
		if status_res != null and status_res is Status:
			status_id = StringName((status_res as Status).get_id())

	if status_id == &"":
		return

	var intensity := int(params.get(Keys.STATUS_INTENSITY, 0))
	var duration := int(params.get(Keys.STATUS_DURATION, 0))
	var actor_id := int(ctx.cid)
	var source_id := int(params.get(Keys.SOURCE_ID, actor_id))
	if source_id <= 0:
		source_id = actor_id

	_begin_scope(
		Scope.Kind.STATUS_ACTION,
		"id=%s tgt=%d" % [String(status_id), int(target_id)],
		actor_id,
		{
			Keys.ACTOR_ID: int(actor_id),
			Keys.SOURCE_ID: int(source_id),
			Keys.TARGET_ID: int(target_id),
			Keys.STATUS_ID: status_id,
			Keys.INTENSITY: int(intensity),
			Keys.DURATION: int(duration),
		}
	)

	var sc := StatusContext.new()
	sc.source_id = source_id
	sc.target_id = target_id
	sc.status_id = status_id
	sc.intensity = intensity
	sc.duration = duration
	api.apply_status(sc)

	_end_scope()


func run_summon_action(ctx: NPCAIContext) -> void:
	var api := _api()
	if api == null or api.state == null or ctx == null or bool(ctx.forecast):
		return

	var params: Dictionary = ctx.params if ctx.params else {}
	var actor_id := int(ctx.cid)
	if actor_id <= 0:
		return

	var source_id := int(params.get(Keys.SOURCE_ID, actor_id))
	if source_id <= 0:
		source_id = actor_id

	var group_index := clampi(int(params.get(Keys.GROUP_INDEX, api.get_group(source_id))), 0, 1)
	var insert_index := int(params.get(Keys.INSERT_INDEX, 0))
	var count := int(params.get(Keys.SUMMON_COUNT, 1))
	if count <= 0:
		return

	var summon_data_orig: CombatantData = _resolve_summon_data(params.get(Keys.SUMMON_DATA, null))
	if summon_data_orig == null:
		push_warning("SimRuntime.run_summon_action(): missing summon_data")
		return

	var n_existing := api.get_combatants_in_group(group_index, false).size()
	if n_existing >= 7:
		return
	if n_existing + count > 7:
		count = 7 - n_existing
		if count <= 0:
			return

	_begin_scope(
		Scope.Kind.SUMMON_ACTION,
		"count=%d g=%d idx=%d" % [count, group_index, insert_index],
		actor_id,
		{
			Keys.ACTOR_ID: int(actor_id),
			Keys.SOURCE_ID: int(source_id),
			Keys.GROUP_INDEX: int(group_index),
			Keys.INSERT_INDEX: int(insert_index),
			Keys.SUMMON_COUNT: int(count),
			Keys.PROTO: String(summon_data_orig.resource_path),
		}
	)

	for _i in range(count):
		var cur_n := api.get_combatants_in_group(group_index, false).size()
		var idx := clampi(insert_index, 0, cur_n)

		var sc := SummonContext.new()
		sc.source_id = source_id
		sc.group_index = group_index
		sc.insert_index = idx

		var cd := summon_data_orig.duplicate(true) as CombatantData
		if cd != null:
			cd.init()
		sc.summon_data = cd

		api.summon(sc)

	_end_scope()


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

	_begin_scope(Scope.Kind.MOVE, "actor=%d" % int(ctx.actor_id), int(ctx.actor_id), extra)
	api.resolve_move(ctx)
	_end_scope()


func run_fade(combat_id: int, reason: String = "fade") -> void:
	var api := _api()
	if api == null or api.state == null or combat_id <= 0:
		return

	var u: CombatantState = api.state.get_unit(int(combat_id))
	if u == null or !u.alive:
		return

	_begin_scope(Scope.Kind.FADE, "fade_unit", int(combat_id))
	api.fade_unit(int(combat_id), String(reason))
	_end_scope()


func run_arcana_proc(proc: int) -> void:
	var api := _api()
	var engine := _engine()
	if api == null or engine == null or sim == null or sim.state == null:
		return
	if host == null or host.arcana_catalog == null:
		push_warning("SimRuntime: no arcana_catalog; cannot run arcana")
		return

	_begin_scope(Scope.Kind.ARCANA, "proc=%d" % int(proc), 0)
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
			_begin_scope(Scope.Kind.ARCANUM, "id=%s" % String(id), player_id)

			var ctx := ArcanumContext.new()
			ctx.api = sim.api
			ctx.runtime = self
			ctx.params[Keys.MODE] = Keys.MODE_SIM
			ctx.params[Keys.PLAYER_ID] = sim.state.groups[0].player_id
			ctx.params[Keys.SOURCE_ID] = sim.state.groups[0].player_id
			ctx.params[Keys.GROUP_INDEX] = 0

			if writer != null:
				writer.emit_arcanum_proc(ctx.params[Keys.SOURCE_ID], id, proc)
			var r = proto.activate_arcanum(ctx)

			if r is Signal and !(r as Signal).is_null():
				push_warning("SimRuntime: arcana %s returned Signal; ignored" % String(id))
			elif typeof(r) == TYPE_OBJECT and r != null and r.get_class() == "GDScriptFunctionState":
				push_warning("SimRuntime: arcana %s returned FunctionState; ignored" % String(id))

			_end_scope()

	_apply_checkpoint_boundary(CheckpointProcessor.Kind.AFTER_ARCANA, true)
	_end_scope()


func apply_attack_now(spec: SimAttackSpec) -> bool:
	var api := _api()
	if api == null or api.state == null or spec == null:
		return false
	if int(spec.attacker_id) <= 0 or !api.is_alive(int(spec.attacker_id)):
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

	for m in spec.param_models:
		if m != null:
			m.change_params_sim(ai_ctx)

	return run_attack(ai_ctx)


func _begin_scope(kind: int, label: String, actor_id: int = 0, extra := {}) -> int:
	var writer := _writer()
	if writer == null:
		return 0
	return writer.scope_begin(kind, label, actor_id, extra)


func _end_scope() -> int:
	var writer := _writer()
	if writer == null:
		return 0
	return writer.scope_end()


func _finish_npc_turn(ctx: NPCAIContext) -> void:
	if ctx == null or ctx.state == null:
		return

	ctx.state[ActionPlanner.IS_ACTING] = false
	ctx.state[ActionPlanner.STABILITY_BROKEN] = false


func _should_immediately_replan_intent(api: SimBattleAPI, u: CombatantState) -> bool:
	if api == null or u == null or u.combatant_data == null:
		return false
	if int(u.team) != int(SimBattleAPI.FRIENDLY):
		return false
	return int(u.id) != int(api.get_player_id())


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
	ctx.card_scope_id = 0
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

	ctx.card_scope_id = ctx.api.writer.scope_begin(
		Scope.Kind.CARD,
		label,
		int(ctx.source_id),
		{}
	)
	ctx.card_scope_opened = (ctx.card_scope_id > 0)
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
		var cost := int(ctx.card_data.get_total_cost())
		if !ctx.api.spend_mana_for_card(int(ctx.source_id), ctx.card_data):
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

	ctx.api.writer.scope_end()
	ctx.card_scope_opened = false
	ctx.card_scope_id = 0


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
