# sim_projected_arcanum_status_context.gd

class_name SimProjectedArcanumStatusContext extends SimStatusContext

const SimArcanumContextScript = preload("res://battle/sim/containers/sim_arcanum_context.gd")

var arcanum_owner_id: int = 0
var arcanum_entry: ArcanaState.ArcanumEntry = null
var arcanum_proto: Arcanum = null
var projected_status_id: StringName = &""


func _init(
	_api = null,
	_target_id: int = 0,
	_target_owner: CombatantState = null,
	_arcanum_owner_id: int = 0,
	_arcanum_entry: ArcanaState.ArcanumEntry = null,
	_arcanum_proto: Arcanum = null,
	_projected_proto: Status = null
) -> void:
	api = _api
	owner_id = int(_target_id)
	owner = _target_owner
	arcanum_owner_id = int(_arcanum_owner_id)
	arcanum_entry = _arcanum_entry
	arcanum_proto = _arcanum_proto
	proto = _projected_proto
	projected_status_id = (
		StringName(_projected_proto.get_id())
		if _projected_proto != null
		else &""
	)


func is_valid() -> bool:
	return (
		api != null
		and owner != null
		and proto != null
		and arcanum_entry != null
		and arcanum_proto != null
		and arcanum_owner_id > 0
		and owner_id > 0
	)


func get_status_id() -> StringName:
	return projected_status_id


func get_intensity() -> int:
	if arcanum_proto == null:
		return 0
	return int(arcanum_proto.get_projection_intensity(_make_arcanum_ctx()))


func get_duration() -> int:
	if arcanum_proto == null:
		return 0
	return int(arcanum_proto.get_projection_duration(_make_arcanum_ctx()))


func is_pending() -> bool:
	return false


func make_token_ctx() -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.id = get_status_id()
	ctx.pending = false
	ctx.intensity = get_intensity()
	ctx.duration = get_duration()
	ctx.owner = null
	ctx.owner_id = owner_id
	return ctx


func _make_arcanum_ctx():
	return SimArcanumContextScript.new(
		api,
		arcanum_owner_id,
		SimBattleAPI.FRIENDLY,
		arcanum_entry,
		arcanum_proto
	)
