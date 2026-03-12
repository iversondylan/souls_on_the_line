# sim_status_runner.gd

class_name SimStatusRunner extends RefCounted

static func run(api: SimBattleAPI, ctx: NPCAIContext) -> void:
	if api == null or api.state == null or ctx == null:
		return
	if bool(ctx.forecast):
		return

	var params: Dictionary = ctx.params if ctx.params else {}

	var target_id := int(ParamModel._actor_id(ctx))
	if target_id <= 0:
		target_id = int(ctx.cid)
	if target_id <= 0:
		return

	# Resolve status_id (same rules as your LIVE sequence)
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

	var source_id := int(params.get(Keys.SOURCE_ID, target_id))

	# Beat markers FIRST (application happens during beat 2)
	#if api.writer != null:
		#api.writer.emit_status_windup(source_id, target_id, status_id, intensity, duration)
		#api.writer.emit_status_followthrough(source_id, target_id, status_id, intensity, duration)

	var sc := StatusContext.new()
	sc.source_id = source_id
	sc.target_id = target_id
	sc.status_id = status_id
	sc.intensity = intensity
	sc.duration = duration
	api.apply_status(sc)
