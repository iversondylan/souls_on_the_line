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
	var api: BattleAPI = ctx.api
	if !api and ctx.battle_scene:
		api = ctx.battle_scene.api
	if !api:
		on_done.call()
		return

	# Resolve target combat_id (self)
	var target_id := 0
	if ctx.combatant:
		target_id = int(ctx.combatant.combat_id)
	elif ctx.combatant_data:
		target_id = int(ctx.combatant_data.combat_id)

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
	sc.target_id = target_id
	sc.source_id = target_id # optional (self as source)
	sc.status_id = status_id
	sc.duration = duration
	sc.intensity = intensity

	api.apply_status(sc)

	on_done.call()

func execute_sim(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast):
		return
	if ctx.api == null or !(ctx.api is SimBattleAPI):
		push_warning("NPCStatusSequence.execute_sim: ctx.api is not SimBattleAPI")
		return
	SimStatusRunner.run(ctx.api as SimBattleAPI, ctx)
