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

func is_pending() -> bool:
	return bool(stack.pending) if stack != null else false


func get_group_index() -> int:
	return int(owner.team) if owner != null else -1


func is_alive() -> bool:
	return owner != null and owner.is_alive()


func make_token_ctx() -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.id = get_status_id()
	ctx.pending = is_pending()
	ctx.intensity = get_intensity()
	ctx.duration = get_duration()
	ctx.owner = null
	ctx.owner_id = owner_id
	return ctx


# -------------------------------------------------------------------
# Controlled mutation helpers
# -------------------------------------------------------------------

func change_intensity(delta: int, reason: String = "") -> void:
	if !is_valid():
		return
	if int(delta) == 0:
		return

	var before_i := int(stack.intensity)
	var before_d := int(stack.duration)
	var after_i := before_i + int(delta)

	stack.intensity = after_i

	if api.writer != null:
		api.writer.emit_status(
			owner_id,
			owner_id,
			get_status_id(),
			int(Status.OP.CHANGE),
			int(delta),
			0,
			{
				Keys.DELTA_INTENSITY: int(delta),
				Keys.DELTA_DURATION: 0,
				Keys.BEFORE_INTENSITY: before_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_INTENSITY: int(stack.intensity),
				Keys.AFTER_DURATION: int(stack.duration),
				Keys.STATUS_PENDING: bool(is_pending()),
				Keys.BEFORE_PENDING: bool(is_pending()),
				Keys.AFTER_PENDING: bool(is_pending()),
				Keys.REASON: String(reason),
			}
		)


func change_duration(delta: int, reason: String = "") -> void:
	if !is_valid():
		return
	if int(delta) == 0:
		return

	var before_i := int(stack.intensity)
	var before_d := int(stack.duration)
	var after_d := before_d + int(delta)

	stack.duration = after_d

	if api.writer != null:
		api.writer.emit_status(
			owner_id,
			owner_id,
			get_status_id(),
			int(Status.OP.CHANGE),
			0,
			int(delta),
			{
				Keys.DELTA_INTENSITY: 0,
				Keys.DELTA_DURATION: int(delta),
				Keys.BEFORE_INTENSITY: before_i,
				Keys.BEFORE_DURATION: before_d,
				Keys.AFTER_INTENSITY: int(stack.intensity),
				Keys.AFTER_DURATION: int(stack.duration),
				Keys.STATUS_PENDING: bool(is_pending()),
				Keys.BEFORE_PENDING: bool(is_pending()),
				Keys.AFTER_PENDING: bool(is_pending()),
				Keys.REASON: String(reason),
			}
		)


func remove_self(_reason: String = "") -> void:
	if !is_valid():
		return

	var rc := StatusContext.new()
	rc.source_id = owner_id
	rc.target_id = owner_id
	rc.status_id = get_status_id()
	rc.pending = is_pending()
	api.remove_status(rc)


func request_removal(
	removal_type: int,
	reason: String = "",
	killer_id: int = 0,
	origin_card_uid: String = "",
	origin_arcanum_id: StringName = &""
) -> void:
	if !is_valid() or api == null or owner == null or !owner.is_alive():
		return

	var removal_ctx = RemovalContext.new()
	removal_ctx.target_id = owner_id
	removal_ctx.removal_type = removal_type
	removal_ctx.killer_id = int(killer_id)
	removal_ctx.group_index = int(owner.team)
	removal_ctx.reason = String(reason)
	removal_ctx.origin_card_uid = String(origin_card_uid)
	removal_ctx.origin_arcanum_id = origin_arcanum_id
	api.resolve_removal(removal_ctx)


func get_active_delayed_reaction() -> DelayedReaction:
	if api == null or api.runtime == null:
		return null
	return api.runtime.get_active_delayed_reaction()


func get_active_removal_reaction():
	var reaction := get_active_delayed_reaction()
	return reaction


func request_replan() -> void:
	if api == null:
		return
	api._request_replan(owner_id)


func request_intent_refresh() -> void:
	if api == null:
		return
	api._request_intent_refresh(owner_id)


func request_intent_refresh_all() -> void:
	if api == null:
		return
	api._request_intent_refresh_all()


func ensure_ai_state() -> void:
	if owner == null:
		return
	ActionPlanner.ensure_ai_state_initialized(owner)
