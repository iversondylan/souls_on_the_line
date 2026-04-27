# sim_arcanum_context.gd

class_name SimArcanumContext extends RefCounted

var api: SimBattleAPI
var owner_id: int = 0
var owner_group_index: int = SimBattleAPI.FRIENDLY
var entry: ArcanumEntry = null
var proto: Arcanum = null


func _init(
	_api: SimBattleAPI = null,
	_owner_id: int = 0,
	_owner_group_index: int = SimBattleAPI.FRIENDLY,
	_entry: ArcanumEntry = null,
	_proto: Arcanum = null
) -> void:
	api = _api
	owner_id = int(_owner_id)
	owner_group_index = int(_owner_group_index)
	entry = _entry
	proto = _proto


func is_valid() -> bool:
	return api != null and entry != null and proto != null and owner_id > 0 and entry.id != &""


func get_arcanum_id() -> StringName:
	return entry.id if entry != null else &""


func get_intensity(default_value := 0) -> int:
	return get_data_int(Keys.INTENSITY, default_value)


func get_duration(default_value := 0) -> int:
	return get_data_int(Keys.DURATION, default_value)


func get_stacks(default_value := -1) -> int:
	if entry == null:
		return int(default_value)
	return int(entry.stacks)


func get_data_int(key, default_value := 0) -> int:
	if entry == null or entry.data == null:
		return int(default_value)
	return int(entry.data.get(key, default_value))


func get_data_bool(key, default_value := false) -> bool:
	if entry == null or entry.data == null:
		return bool(default_value)
	return bool(entry.data.get(key, default_value))


func get_data_string_name(key, default_value: StringName = &"") -> StringName:
	if entry == null or entry.data == null:
		return default_value
	return StringName(entry.data.get(key, default_value))


func set_data(key, value) -> void:
	if entry == null:
		return
	entry.data[key] = value
	if api != null:
		api._sync_arcanum_source_transformers(get_arcanum_id())


func set_intensity(value: int) -> void:
	set_data(Keys.INTENSITY, int(value))


func set_duration(value: int) -> void:
	set_data(Keys.DURATION, int(value))


func change_intensity(delta: int) -> int:
	var next_value := get_intensity(0) + int(delta)
	set_intensity(next_value)
	return next_value


func change_duration(delta: int) -> int:
	var next_value := get_duration(0) + int(delta)
	set_duration(next_value)
	return next_value


func set_stacks(value: int, reason: String = "") -> void:
	if entry == null:
		return

	var before_stacks := int(entry.stacks)
	var after_stacks := int(value)
	entry.stacks = after_stacks

	if api != null and api.writer != null and before_stacks != after_stacks:
		api.writer.emit_arcanum_state_changed(
			int(owner_id),
			get_arcanum_id(),
			before_stacks,
			after_stacks,
			reason
		)
	if api != null and before_stacks != after_stacks:
		api._sync_arcanum_source_transformers(get_arcanum_id())


func change_stacks(delta: int, reason: String = "") -> int:
	var next_value := get_stacks(-1) + int(delta)
	set_stacks(next_value, reason)
	return get_stacks(-1)


func make_token_ctx(owner_override: int = -1) -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.id = get_arcanum_id()
	ctx.pending = false
	ctx.intensity = get_intensity(0)
	ctx.duration = get_duration(0)
	ctx.owner = null
	ctx.owner_id = owner_id if int(owner_override) < 0 else int(owner_override)
	return ctx


func request_replan(cid: int) -> void:
	if api == null:
		return
	api._request_replan(int(cid))


func request_intent_refresh(cid: int) -> void:
	if api == null:
		return
	api._request_intent_refresh(int(cid))


func request_intent_refresh_all() -> void:
	if api == null:
		return
	api._request_intent_refresh_all()
