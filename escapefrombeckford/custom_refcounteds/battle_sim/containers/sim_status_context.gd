# sim_status_context.gd

class_name SimStatusContext extends RefCounted

# Runtime wrapper for a specific status stack on a specific owner.
# This keeps proto Status scripts from reaching all over raw state.

var api: SimBattleAPI
var owner_id: int = 0
var owner: CombatantState
var stack: StatusStack
var proto: Status

func _init(
	_api: SimBattleAPI = null,
	_owner_id: int = 0,
	_owner: CombatantState = null,
	_stack: StatusStack = null,
	_proto: Status = null
) -> void:
	api = _api
	owner_id = int(_owner_id)
	owner = _owner
	stack = _stack
	proto = _proto

func is_valid() -> bool:
	return api != null and owner != null and stack != null and proto != null and owner_id > 0

func get_status_id() -> StringName:
	return stack.id if stack != null else &""

func get_intensity() -> int:
	return int(stack.intensity) if stack != null else 0

func get_duration() -> int:
	return int(stack.duration) if stack != null else 0

func get_group_index() -> int:
	return int(owner.team) if owner != null else -1

func is_alive() -> bool:
	return owner != null and owner.is_alive()

func make_token_ctx() -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.id = get_status_id()
	ctx.intensity = get_intensity()
	ctx.duration = get_duration()
	ctx.owner = null
	ctx.owner_id = owner_id
	return ctx
