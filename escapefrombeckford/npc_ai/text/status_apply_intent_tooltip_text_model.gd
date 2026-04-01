class_name StatusApplyIntentTooltipTextModel extends TextModel

@export_multiline var text_template: String = "[b]{action_name}[/b] [{target}]: apply {stacks}{status}."

func get_text(ctx: NPCAIContext) -> String:
	if ctx == null:
		return text_template

	var result := text_template
	var actor_id := int(ctx.cid)
	var status_proto := _resolve_status_proto(ctx)

	result = result.replace("{action_name}", String(ctx.action_name))
	result = result.replace("{target}", _build_target_text(ctx, actor_id))
	result = result.replace("{stacks}", _build_stacks_text(ctx, status_proto))
	result = result.replace("{status}", _build_status_text(status_proto))

	return result

func _resolve_status_proto(ctx: NPCAIContext) -> Status:
	if ctx == null or ctx.params == null or ctx.api == null or ctx.api.state == null:
		return null

	var status_id = _param_v(ctx, Keys.STATUS_ID, &"")
	if status_id is String:
		status_id = StringName(status_id)
	elif !(status_id is StringName):
		status_id = &""

	if StringName(status_id) == &"" or ctx.api.state.status_catalog == null:
		return null

	return ctx.api.state.status_catalog.get_proto(StringName(status_id))

func _build_status_text(proto: Status) -> String:
	if proto == null or String(proto.status_name).is_empty():
		return "[status unknown]"
	return String(proto.status_name)

func _build_stacks_text(ctx: NPCAIContext, proto: Status) -> String:
	if ctx == null or proto == null:
		return ""

	match int(proto.number_display_type):
		Status.NumberDisplayType.INTENSITY:
			return "%d " % _param_i(ctx, Keys.STATUS_INTENSITY, 0)
		Status.NumberDisplayType.DURATION:
			return "%d " % _param_i(ctx, Keys.STATUS_DURATION, 0)
		_:
			return ""

func _build_target_text(ctx: NPCAIContext, actor_id: int) -> String:
	var names := _resolved_target_names(ctx, actor_id)
	if names.is_empty():
		return "target: self"
	if names.size() == 1:
		return "target: %s" % names[0]
	return "targets: %s" % _join_names(names)

func _resolved_target_names(ctx: NPCAIContext, actor_id: int) -> Array[String]:
	var target_ids := _resolved_target_ids(ctx)
	var out: Array[String] = []

	if target_ids.is_empty():
		out.append("self")
		return out

	for tid in target_ids:
		var target_id := int(tid)
		if target_id == actor_id:
			out.append("self")
			continue

		var name := _combatant_name(ctx, target_id)
		if name.is_empty():
			continue
		out.append(name)

	if out.is_empty():
		out.append("self")

	return out

func _resolved_target_ids(ctx: NPCAIContext) -> PackedInt32Array:
	var out := PackedInt32Array()
	if ctx == null or ctx.params == null:
		return out

	var seen := {}
	var raw_value = ctx.params.get(Keys.TARGET_IDS, PackedInt32Array())
	var raw_ids := PackedInt32Array()

	if raw_value is PackedInt32Array:
		raw_ids = raw_value
	elif raw_value is Array:
		raw_ids = PackedInt32Array(raw_value)

	for tid in raw_ids:
		var target_id := int(tid)
		if target_id <= 0 or seen.has(target_id):
			continue
		seen[target_id] = true
		if ctx.api != null and ctx.api.state != null:
			var unit := ctx.api.state.get_unit(target_id)
			if unit == null or !unit.is_alive():
				continue
		out.append(target_id)

	return out

func _combatant_name(ctx: NPCAIContext, target_id: int) -> String:
	if ctx == null or ctx.api == null or ctx.api.state == null:
		return ""

	var unit: CombatantState = ctx.api.state.get_unit(int(target_id))
	if unit == null or unit.combatant_data == null:
		return ""

	return String(unit.combatant_data.name)

func _join_names(names: Array[String]) -> String:
	if names.size() <= 0:
		return ""
	if names.size() == 1:
		return names[0]
	if names.size() == 2:
		return "%s and %s" % [names[0], names[1]]

	var prefix := ", ".join(names.slice(0, names.size() - 1))
	return "%s, and %s" % [prefix, names[names.size() - 1]]
