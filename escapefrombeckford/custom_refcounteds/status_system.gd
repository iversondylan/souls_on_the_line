# status_system.gd

class_name StatusSystem extends RefCounted

signal changed()
signal status_added(id: StringName)
signal status_removed(id: StringName)
signal status_changed(id: StringName)
signal intent_conditions_changed()
signal modifier_tokens_changed(mod_type: Modifier.Type)

var owner: Fighter = null
var catalog: StatusCatalog = null

# id -> Status (runtime instance, typically proto.duplicate())
var by_id: Dictionary = {}

func _init(_owner: Fighter = null, _catalog: StatusCatalog = null) -> void:
	owner = _owner
	catalog = _catalog

func has_status(id: StringName) -> bool:
	return by_id.has(id)

func get_status(id: StringName) -> Status:
	return by_id.get(id, null)

func get_all() -> Array[Status]:
	#print("status_system.gd get_all()")
	var out: Array[Status] = []
	for s in by_id.values():
		if s:
			out.append(s)
	return out

# ----------------------------
# Mutation / Reapply
# ----------------------------

func add_or_reapply(proto: Status, duration: int, intensity: int) -> void:
	if !proto:
		return

	var inst: Status = proto.duplicate()
	inst.duration = duration
	inst.intensity = intensity
	add_status(inst)

func add_status(incoming: Status) -> void:
	if !incoming:
		return

	var id := StringName(incoming.get_id())
	if id == &"":
		return

	if incoming.affects_intent_legality():
		intent_conditions_changed.emit()

	if !by_id.has(id):
		_add_new_status(incoming)
		return

	var existing: Status = by_id[id]
	if !existing:
		_add_new_status(incoming)
		return

	match incoming.reapply_type:
		Status.ReapplyType.REPLACE:
			remove_status_by_id(String(id))
			_add_new_status(incoming)
			return

		Status.ReapplyType.DURATION:
			if incoming.expiration_policy == Status.ExpirationPolicy.DURATION:
				existing.duration += incoming.duration
				_mark_dirty_for_status(existing)
				_emit_status_changed(existing)
			return

		Status.ReapplyType.INTENSITY:
			existing.intensity += incoming.intensity
			_mark_dirty_for_status(existing)
			_emit_status_changed(existing)
			return

		Status.ReapplyType.IGNORE:
			return

func remove_status(id: StringName, _remove_all_stacks: bool = true) -> int:
	return remove_status_by_id(String(id))

func remove_status_by_id(id: String) -> int:
	if id == "":
		return 0
	var key := StringName(id)
	if !by_id.has(key):
		return 0

	var s: Status = by_id[key]
	_remove_status_instance(s)
	return 1

func _add_new_status(status: Status) -> void:
	var s := status
	if owner:
		s.status_parent = owner

	# Connect (no is_connected/bind checks)
	s.status_changed.connect(_on_status_changed.bind(StringName(s.get_id())))
	s.status_applied.connect(_on_status_applied.bind(StringName(s.get_id())))

	s.init_status(owner)

	var id := StringName(s.get_id())
	by_id[id] = s

	_mark_dirty_for_status(s)
	status_added.emit(id)
	changed.emit()

func _remove_status_instance(status: Status) -> void:
	if !status:
		return
	var id := StringName(status.get_id())

	status.on_removed()

	by_id.erase(id)

	# Dirty modifiers on removal
	if status.contributes_modifier():
		for mod_type in status.get_contributed_modifier_types():
			if owner:
				owner.modifier_system.mark_dirty(mod_type)
			if status.affects_others():
				modifier_tokens_changed.emit(mod_type)

	if status.affects_intent_legality():
		intent_conditions_changed.emit()

	status_removed.emit(id)
	changed.emit()

# ----------------------------
# Proc application & expiry
# ----------------------------

func apply_proc(proc_type: Status.ProcType) -> void:
	# For sim: apply immediately (no tween).
	if proc_type == Status.ProcType.EVENT_BASED:
		return

	for s in get_all():
		if s and s.proc_type == proc_type:
			print("status_system.gd apply_proc() owner: %s, cid: %s, proc_type: %s, status: %s" % [owner.name, owner.combat_id, Status.ProcType.keys()[proc_type], s.get_id()])
			s.apply_status(owner)

	# After all apply calls, handle duration ticking for DURATION policy
	_tick_duration_after_proc(proc_type)
	_remove_expired()

func _tick_duration_after_proc(_proc_type: Status.ProcType) -> void:
	# This matches your old behavior: every time a status is applied and has DURATION policy,
	# duration-- happens in _on_status_applied(). But that was per-status signal.
	# Here we can keep it per-status signal OR do a pass.
	# If you want EXACT old behavior: keep _on_status_applied() doing duration--.

	pass

func _on_status_applied(_status: Status, id: StringName) -> void:
	var s: Status = by_id.get(id, null)
	if !s:
		return
	if s.expiration_policy == Status.ExpirationPolicy.DURATION:
		s.duration -= 1
	_emit_status_changed(s)
	_remove_expired()


func _remove_expired() -> void:
	var to_remove: Array[StringName] = []
	for id in by_id.keys():
		var s: Status = by_id[id]
		if s and s.is_expired():
			to_remove.append(id)

	for id in to_remove:
		var s: Status = by_id.get(id, null)
		_remove_status_instance(s)

func clear_group_turn_end_statuses() -> void:
	var to_remove: Array[StringName] = []
	for id in by_id.keys():
		var s: Status = by_id[id]
		if s and s.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_END:
			to_remove.append(id)
	for id in to_remove:
		_remove_status_instance(by_id.get(id, null))

func clear_group_turn_start_statuses() -> void:
	var to_remove: Array[StringName] = []
	for id in by_id.keys():
		var s: Status = by_id[id]
		if s and s.expiration_policy == Status.ExpirationPolicy.GROUP_TURN_START:
			to_remove.append(id)
	for id in to_remove:
		_remove_status_instance(by_id.get(id, null))

func end_non_self_statuses() -> void:
	var to_remove: Array[StringName] = []
	for id in by_id.keys():
		var s: Status = by_id[id]
		if s and s.affects_others():
			if s.expiration_policy == Status.ExpirationPolicy.DURATION:
				s.duration = 0
				_emit_status_changed(s)
			else:
				to_remove.append(id)

	for id in to_remove:
		_remove_status_instance(by_id.get(id, null))

	_remove_expired()

# ----------------------------
# Event-based hooks
# ----------------------------

func on_damage_taken(ctx: DamageContext) -> void:
	for s in get_all():
		if s and s.proc_type == Status.ProcType.EVENT_BASED:
			s.on_damage_taken(ctx)

# ----------------------------
# Modifier tokens
# ----------------------------

func get_modifier_tokens() -> Array[ModifierToken]:
	#if owner and owner.combat_id:
		#print("status_system.gd get_modifier_tokens() owner id: %s, name: %s" % [owner.combat_id, owner.name])
	var tokens: Array[ModifierToken] = []
	for s in get_all():
		#print("status_system.gd get_modifier_tokens() has status: ", s.get_id())
		if !s:
			continue
		if s.is_expired():
			continue
		if s.contributes_modifier():
			var ctx := s.make_token_ctx_node(owner)
			ctx.owner_id = owner.combat_id
			tokens.append_array(s.get_modifier_tokens(ctx))
	return tokens

func _mark_dirty_for_status(status: Status) -> void:
	if !status or !status.contributes_modifier():
		return
	for mod_type in status.get_contributed_modifier_types():
		if owner:
			owner.modifier_system.mark_dirty(mod_type)
		if status.affects_others():
			modifier_tokens_changed.emit(mod_type)

func _emit_status_changed(status: Status) -> void:
	if !status:
		return
	var id := StringName(status.get_id())
	status_changed.emit(id)
	changed.emit()

func _on_status_changed(id: StringName) -> void:
	var s: Status = by_id.get(id, null)
	if !s:
		return
	if s.is_expired():
		_remove_expired()
		return
	_mark_dirty_for_status(s)
	status_changed.emit(id)
	changed.emit()

#func on_proc_applied(proc_type: Status.ProcType) -> void:
	#print("status_system.gd on_proc_applied(): this method is not implemented and does nothing.")
	#pass
# ----------------------------
# Serialization (replace StatusGridData/StatusState)
# ----------------------------

func export_state() -> Dictionary:
	# id -> {duration,intensity}
	var out := {}
	for id in by_id.keys():
		var s: Status = by_id[id]
		if !s:
			continue
		out[String(id)] = {"duration": s.duration, "intensity": s.intensity}
	return out

func sync_from_state(state: Dictionary, _catalog: StatusCatalog) -> void:
	if !_catalog or !state:
		return

	# Clear existing
	for id in by_id.keys():
		_remove_status_instance(by_id[id])

	# Build new
	for id_str in state.keys():
		var proto := _catalog.get_proto(id_str)
		if !proto:
			continue
		var inst: Status = proto.duplicate()
		var blob: Dictionary = state[id_str]
		inst.duration = int(blob.get("duration", 0))
		inst.intensity = int(blob.get("intensity", 0))
		add_status(inst)
