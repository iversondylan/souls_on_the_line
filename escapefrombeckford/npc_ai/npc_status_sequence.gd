# npc_status_sequence.gd

class_name NPCStatusSequence extends NPCEffectSequence

func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	# Always finish
	if !ctx:
		on_done.call()
		return

	# Strictly stateless during forecast
	if bool(ctx.forecast):
		on_done.call()
		return

	# Resolve API
	var api: SimBattleAPI = ctx.api
	if !api and ctx.battle_scene:
		api = ctx.battle_scene.api
	if !api:
		on_done.call()
		return

	# Resolve target combat_id (self)
	var target_id := int(ParamModel._actor_id(ctx))
	if target_id <= 0:
		on_done.call()
		return

	# -------------------------
	# Resolve status identifier
	# -------------------------
	# Preferred: callers set Keys.STATUS_ID to a StringName like &"amplify"
	var status_id: StringName = &""

	if ctx.params.has(Keys.STATUS_ID):
		var v = ctx.params[Keys.STATUS_ID]
		if v is StringName:
			status_id = v
		elif v is String:
			status_id = StringName(v)

	# Back-compat: old callers pass a Status resource in Keys.STATUS_SCENE
	if status_id == &"":
		var status_res = ctx.params.get(Keys.STATUS_SCENE, null)
		if status_res and status_res is Status:
			status_id = StringName((status_res as Status).get_id())

	if status_id == &"":
		on_done.call()
		return

	# -------------------------
	# Optional numeric overrides
	# -------------------------
	var intensity := 0
	var duration := 0

	if ctx.params.has(Keys.STATUS_INTENSITY):
		intensity = int(ctx.params[Keys.STATUS_INTENSITY])

	if ctx.params.has(Keys.STATUS_DURATION):
		duration = int(ctx.params[Keys.STATUS_DURATION])

	# -------------------------
	# Build context + apply via API
	# -------------------------
	var sc := StatusContext.new()
	sc.actor_id = target_id
	sc.target_id = target_id
	sc.source_id = target_id
	sc.status_id = status_id
	sc.duration = duration
	sc.intensity = intensity

	api.apply_status(sc)

	on_done.call()

func execute_sim(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast):
		return
	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("NPCStatusSequence.execute_sim: missing runtime")
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

	var status_ctx := StatusContext.new()
	status_ctx.actor_id = int(ctx.cid)
	status_ctx.source_id = int(params.get(Keys.SOURCE_ID, ctx.cid))
	status_ctx.target_id = target_id
	status_ctx.status_id = status_id
	status_ctx.intensity = int(params.get(Keys.STATUS_INTENSITY, 0))
	status_ctx.duration = int(params.get(Keys.STATUS_DURATION, 0))
	status_ctx.reason = "npc_status_action"
	runtime.run_status_action(status_ctx)
