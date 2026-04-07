# sim_aura_status_context.gd

class_name SimAuraStatusContext extends SimStatusContext

var aura_source_id: int = 0
var aura_source: CombatantState = null
var aura_status_id: StringName = &""
var aura_pending: bool = false
var aura_proto: Aura = null
var projected_status_id: StringName = &""


func _init(
	_api = null,
	_target_id: int = 0,
	_target_owner: CombatantState = null,
	_aura_source_id: int = 0,
	_aura_source: CombatantState = null,
	_aura_status_id: StringName = &"",
	_aura_pending := false,
	_aura_proto: Aura = null,
	_projected_proto: Status = null
) -> void:
	api = _api
	owner_id = int(_target_id)
	owner = _target_owner
	aura_source_id = int(_aura_source_id)
	aura_source = _aura_source
	aura_status_id = StringName(_aura_status_id)
	aura_pending = bool(_aura_pending)
	aura_proto = _aura_proto
	proto = _projected_proto
	projected_status_id = (
		StringName(_projected_proto.get_id())
		if _projected_proto != null
		else &""
	)
	stack = _get_aura_stack()


func is_valid() -> bool:
	return (
		api != null
		and owner != null
		and proto != null
		and aura_source_id > 0
		and aura_proto != null
		and owner_id > 0
		and _get_aura_stack() != null
	)


func get_status_id() -> StringName:
	return projected_status_id


func get_intensity() -> int:
	var aura_stack := _get_aura_stack()
	return int(aura_stack.intensity) if aura_stack != null else 0


func get_duration() -> int:
	var aura_stack := _get_aura_stack()
	return int(aura_stack.duration) if aura_stack != null else 0


func is_pending() -> bool:
	var aura_stack := _get_aura_stack()
	return bool(aura_stack.pending) if aura_stack != null else aura_pending


func make_token_ctx() -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.id = get_status_id()
	ctx.pending = is_pending()
	ctx.intensity = get_intensity()
	ctx.duration = get_duration()
	ctx.owner = null
	ctx.owner_id = owner_id
	return ctx


func change_intensity(delta: int, reason: String = "") -> void:
	var aura_stack := _get_aura_stack()
	if !is_valid() or aura_stack == null or int(delta) == 0:
		return

	var before_i := int(aura_stack.intensity)
	var before_d := int(aura_stack.duration)
	aura_stack.intensity = before_i + int(delta)

	if api.writer != null:
		api.writer.emit_status(
			aura_source_id,
			aura_source_id,
			aura_status_id,
			int(Status.OP.CHANGE),
			int(delta),
			0,
			{
				Keys.DELTA_INTENSITY: int(delta),
				Keys.DELTA_DURATION: 0,
				Keys.BEFORE_INTENSITY: before_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_INTENSITY: int(aura_stack.intensity),
				Keys.AFTER_DURATION: int(aura_stack.duration),
				Keys.STATUS_PENDING: bool(is_pending()),
				Keys.BEFORE_PENDING: bool(is_pending()),
				Keys.AFTER_PENDING: bool(is_pending()),
				Keys.REASON: String(reason),
			}
		)

	_after_aura_mutation()


func change_duration(delta: int, reason: String = "") -> void:
	var aura_stack := _get_aura_stack()
	if !is_valid() or aura_stack == null or int(delta) == 0:
		return

	var before_i := int(aura_stack.intensity)
	var before_d := int(aura_stack.duration)
	aura_stack.duration = before_d + int(delta)

	if api.writer != null:
		api.writer.emit_status(
			aura_source_id,
			aura_source_id,
			aura_status_id,
			int(Status.OP.CHANGE),
			0,
			int(delta),
			{
				Keys.DELTA_INTENSITY: 0,
				Keys.DELTA_DURATION: int(delta),
				Keys.BEFORE_INTENSITY: before_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_INTENSITY: int(aura_stack.intensity),
				Keys.AFTER_DURATION: int(aura_stack.duration),
				Keys.STATUS_PENDING: bool(is_pending()),
				Keys.BEFORE_PENDING: bool(is_pending()),
				Keys.AFTER_PENDING: bool(is_pending()),
				Keys.REASON: String(reason),
			}
		)

	_after_aura_mutation()


func remove_self(_reason: String = "") -> void:
	if !is_valid():
		return

	var rc := StatusContext.new()
	rc.source_id = aura_source_id
	rc.target_id = aura_source_id
	rc.status_id = aura_status_id
	rc.pending = is_pending()
	api.remove_status(rc)


func _after_aura_mutation() -> void:
	if api == null:
		return

	api._refresh_status_aura_projection(aura_source_id, aura_status_id, is_pending())


func _get_aura_stack() -> StatusStack:
	if api == null or api.state == null or aura_source_id <= 0 or aura_status_id == &"":
		return null

	var source_unit: CombatantState = api.state.get_unit(aura_source_id)
	if source_unit == null or source_unit.statuses == null:
		return null

	return source_unit.statuses.get_status_stack(aura_status_id, aura_pending)
