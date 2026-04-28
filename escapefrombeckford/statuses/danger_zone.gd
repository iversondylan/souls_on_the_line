# danger_zone.gd

class_name DangerZoneStatus extends Status

const ID := &"danger_zone"
const RETARGET_PRIORITY := 200

func on_apply(ctx: SimStatusContext, apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null:
		return

	var owner_id := int(ctx.owner_id)
	if owner_id <= 0:
		return

	var owner_group := int(ctx.owner.team)
	var ids := ctx.api.get_combatants_in_group(owner_group, true)

	for other_id in ids:
		var oid := int(other_id)
		if oid <= 0 or oid == owner_id:
			continue

		var remove_ctx := StatusContext.new()
		remove_ctx.source_id = int(apply_ctx.source_id if apply_ctx != null else owner_id)
		remove_ctx.target_id = oid
		remove_ctx.status_id = ID

		ctx.api.remove_status(remove_ctx)

	_refresh_adjacent_target_data(ctx)

func get_id() -> StringName:
	return ID

func get_targeting_priority(stage: int) -> int:
	if int(stage) == int(TargetingContext.Stage.RETARGET):
		return RETARGET_PRIORITY
	return 1000

func listens_for_targeting_retarget() -> bool:
	return true


func on_targeting_retarget(ctx: SimStatusContext, targeting_ctx: TargetingContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.owner == null or targeting_ctx == null or targeting_ctx.api == null:
		return
	if !targeting_ctx.is_single_target_intent:
		return

	var source_id := int(targeting_ctx.source_id)
	if source_id <= 0:
		return

	var source_unit: CombatantState = targeting_ctx.api.state.get_unit(source_id)
	if source_unit == null or source_unit.ai_state == null:
		return
	if !bool(source_unit.ai_state.get(Keys.TARGETING_DANGER_ZONE, false)):
		return

	var owner_id := int(ctx.owner_id)
	if owner_id <= 0 or !targeting_ctx.api.is_alive(owner_id):
		return
	if int(ctx.owner.team) != int(targeting_ctx.defending_group_index):
		return

	var ordered_ids := targeting_ctx.api.get_combatants_in_group(int(ctx.owner.team), false)
	var center_index := ordered_ids.find(owner_id)
	if center_index < 0:
		return

	var retarget_ids: Array[int] = [owner_id]
	if center_index - 1 >= 0:
		retarget_ids.append(int(ordered_ids[center_index - 1]))
	if center_index + 1 < ordered_ids.size():
		retarget_ids.append(int(ordered_ids[center_index + 1]))

	targeting_ctx.redirect_target_id = owner_id
	targeting_ctx.working_target_ids = retarget_ids

func get_tooltip(_stacks: int = 0) -> String:
	return "Danger Zone: the next Danger Zone attack centers here and splashes adjacent allies."


func _refresh_adjacent_target_data(ctx: SimStatusContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or ctx.token == null:
		return

	var adjacent_ids := _get_adjacent_living_ids(ctx)
	var current = ctx.token.data.get(Keys.DANGER_ZONE_ADJACENT_TARGET_IDS, PackedInt32Array()) if ctx.token.data != null else PackedInt32Array()
	if _packed_int_arrays_equal(_coerce_int_array(current), adjacent_ids):
		return

	ctx.set_token_data_value(Keys.DANGER_ZONE_ADJACENT_TARGET_IDS, adjacent_ids, "danger_zone_adjacent_targets_changed")


func _get_adjacent_living_ids(ctx: SimStatusContext) -> PackedInt32Array:
	var out := PackedInt32Array()
	if ctx == null or ctx.api == null or ctx.owner == null:
		return out

	var owner_id := int(ctx.owner_id)
	var ordered_ids := ctx.api.get_combatants_in_group(int(ctx.owner.team), false)
	var center_index := ordered_ids.find(owner_id)
	if center_index < 0:
		return out

	if center_index - 1 >= 0:
		out.append(int(ordered_ids[center_index - 1]))
	if center_index + 1 < ordered_ids.size():
		out.append(int(ordered_ids[center_index + 1]))
	return out


func _coerce_int_array(value: Variant) -> PackedInt32Array:
	if value is PackedInt32Array:
		return value

	var out := PackedInt32Array()
	if value is Array:
		for entry in value:
			out.append(int(entry))
	return out


func _packed_int_arrays_equal(a: PackedInt32Array, b: PackedInt32Array) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if int(a[i]) != int(b[i]):
			return false
	return true
