# sim_status_context.gd

class_name SimStatusContext extends RefCounted


# Runtime wrapper for a specific status token on a specific owner.
# This keeps proto Status scripts from reaching all over raw state.

var api: SimBattleAPI
var owner_id: int = 0
var owner: CombatantState
var token: StatusToken
var proto: Status
var _read_only: bool = false

func _init(
	_api: SimBattleAPI = null,
	_owner_id: int = 0,
	_owner: CombatantState = null,
	_token: StatusToken = null,
	_proto: Status = null,
	_read_only_projected: bool = false
) -> void:
	api = _api
	owner_id = int(_owner_id)
	owner = _owner
	token = _token
	proto = _proto
	_read_only = bool(_read_only_projected)

func is_valid() -> bool:
	return api != null and owner != null and token != null and proto != null and owner_id > 0

func is_read_only() -> bool:
	return bool(_read_only)

func get_status_id() -> StringName:
	return token.id if token != null else &""

func get_stacks() -> int:
	return int(token.stacks) if token != null else 0

func is_pending() -> bool:
	return bool(token.pending) if token != null else false

func get_group_index() -> int:
	return int(owner.team) if owner != null else -1

func is_alive() -> bool:
	return owner != null and owner.is_alive()

func make_token_ctx() -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.api = api
	ctx.id = get_status_id()
	ctx.pending = is_pending()
	ctx.stacks = get_stacks()
	ctx.owner = null
	ctx.owner_id = owner_id
	return ctx

func _can_mutate_self() -> bool:
	return !_read_only

# -------------------------------------------------------------------
# Controlled mutation helpers
# -------------------------------------------------------------------

func change_stacks(delta: int, reason: String = "") -> void:
	if !is_valid() or !_can_mutate_self():
		return
	if int(delta) == 0:
		return

	var before_stacks := int(token.stacks)
	var after_stacks := before_stacks + int(delta)

	if owner != null and owner.statuses != null:
		owner.statuses.set_token(get_status_id(), after_stacks, is_pending())

	if api.writer != null:
		api._emit_status_event(
			owner_id,
			owner_id,
			get_status_id(),
			int(Status.OP.CHANGE),
			int(delta),
			{
			Keys.DELTA_STACKS: int(delta),
			Keys.BEFORE_STACKS: before_stacks,
				Keys.BEFORE_TOKEN_ID: int(token.token_id),
				Keys.AFTER_TOKEN_ID: int(token.token_id),
				Keys.AFTER_STACKS: int(token.stacks),
				Keys.STATUS_PENDING: bool(is_pending()),
				Keys.STATUS_DATA: token.data.duplicate(true),
				Keys.BEFORE_PENDING: bool(is_pending()),
				Keys.AFTER_PENDING: bool(is_pending()),
				Keys.REASON: String(reason),
			}
		)
	if api != null and owner != null:
		api._sync_transformer_source(
			TransformerSourceRef.for_status_token(
				owner_id,
				int(owner.team),
				get_status_id(),
				int(token.token_id)
			)
		)

	if proto != null and bool(proto.numerical) and int(token.stacks) <= 0:
		remove_self(reason if !String(reason).is_empty() else "stacks_depleted")

func remove_self(_reason: String = "") -> void:
	if !is_valid() or !_can_mutate_self():
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
	if !is_valid() or !_can_mutate_self() or api == null or owner == null or !owner.is_alive():
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

func get_token_data_bool(key: StringName, default_value: bool = false) -> bool:
	if token == null or token.data == null:
		return default_value
	return bool(token.data.get(key, default_value))

func get_token_data_int(key: StringName, default_value: int = 0) -> int:
	if token == null or token.data == null:
		return default_value
	return int(token.data.get(key, default_value))

func set_token_data_value(key: StringName, value, reason: String = "") -> void:
	if !is_valid() or !_can_mutate_self() or token == null:
		return
	if token.data == null:
		token.data = {}
	token.data[key] = value
	_emit_token_data_changed(reason)

func set_token_data_dict(values: Dictionary, reason: String = "") -> void:
	if !is_valid() or !_can_mutate_self() or token == null or values == null:
		return
	if token.data == null:
		token.data = {}
	for key in values.keys():
		token.data[key] = values[key]
	_emit_token_data_changed(reason)

func _emit_token_data_changed(reason: String) -> void:
	if !is_valid() or token == null or api == null:
		return

	if api.writer != null:
		api._emit_status_event(
			owner_id,
			owner_id,
			get_status_id(),
			int(Status.OP.CHANGE),
			0,
			{
				Keys.DELTA_STACKS: 0,
				Keys.BEFORE_STACKS: int(token.stacks),
				Keys.BEFORE_TOKEN_ID: int(token.token_id),
				Keys.AFTER_TOKEN_ID: int(token.token_id),
				Keys.AFTER_STACKS: int(token.stacks),
				Keys.STATUS_PENDING: bool(is_pending()),
				Keys.STATUS_DATA: token.data.duplicate(true),
				Keys.BEFORE_PENDING: bool(is_pending()),
				Keys.AFTER_PENDING: bool(is_pending()),
				Keys.REASON: String(reason),
			}
		)
	if api != null and owner != null:
		api._sync_transformer_source(
			TransformerSourceRef.for_status_token(
				owner_id,
				int(owner.team),
				get_status_id(),
				int(token.token_id)
			)
		)
		api._on_status_changed(int(owner_id))
