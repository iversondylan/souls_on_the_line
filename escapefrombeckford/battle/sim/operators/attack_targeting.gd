# attack_targeting.gd

class_name AttackTargeting extends RefCounted

class TargetingParticipant extends RefCounted:
	var priority: int = 100
	var discovery_index: int = 0
	var status_ctx: SimStatusContext = null
	var status_proto: Status = null
	var arcanum_proto: Arcanum = null

static func get_target_ids(ctx: TargetingContext) -> Array[int]:
	if ctx == null or ctx.api == null:
		return []
	if int(ctx.source_id) <= 0:
		return []
	if !bool(ctx.allow_dead_source) and !ctx.api.is_alive(int(ctx.source_id)):
		return []

	ctx.source_group_index = int(ctx.api.get_group(int(ctx.source_id)))
	ctx.defending_group_index = int(ctx.api.get_opposing_group(int(ctx.source_group_index)))

	if !ctx.explicit_target_ids.is_empty():
		ctx.base_target_ids = ctx.explicit_target_ids.duplicate()
	else:
		ctx.base_target_ids = _get_base_target_ids(ctx)

	ctx.base_target_ids = ctx.base_target_ids.filter(func(id):
		return int(id) > 0 and ctx.api.is_alive(int(id))
	)

	ctx.working_target_ids = ctx.base_target_ids.duplicate()
	ctx.is_single_target_intent = _is_single(ctx)
	_run_stage(ctx, TargetingContext.Stage.RETARGET)
	_run_stage(ctx, TargetingContext.Stage.INTERPOSE)
	_finalize_targets(ctx)

	return ctx.final_target_ids


static func get_next_target_id_after(ctx: TargetingContext, current_target_id: int) -> int:
	if ctx == null or ctx.api == null:
		return 0
	if int(current_target_id) <= 0:
		return 0

	var target_type := int(ctx.target_type)
	if target_type != int(Attack.Targeting.STANDARD) and target_type != int(Attack.Targeting.REVERSE):
		return 0

	var defending_group_index := int(ctx.defending_group_index)
	if defending_group_index < 0:
		var source_group_index := int(ctx.api.get_group(int(ctx.source_id)))
		if source_group_index < 0:
			return 0
		defending_group_index = int(ctx.api.get_opposing_group(source_group_index))

	var ordered_ids := ctx.api.get_combatants_in_group(defending_group_index, false)
	var current_index := ordered_ids.find(int(current_target_id))
	if current_index < 0:
		return 0

	if target_type == int(Attack.Targeting.STANDARD):
		for i in range(current_index + 1, ordered_ids.size()):
			var next_id := int(ordered_ids[i])
			if next_id > 0 and ctx.api.is_alive(next_id):
				return next_id
		return 0

	for i in range(current_index - 1, -1, -1):
		var next_id := int(ordered_ids[i])
		if next_id > 0 and ctx.api.is_alive(next_id):
			return next_id
	return 0


static func _get_base_target_ids(ctx: TargetingContext) -> Array[int]:
	var out: Array[int] = []
	var target_type := int(ctx.target_type)

	match target_type:
		Attack.Targeting.STANDARD:
			var my_group := ctx.api.get_group(int(ctx.source_id))
			if my_group < 0:
				return out

			var opp := ctx.api.get_opposing_group(my_group)
			var front := ctx.api.get_front_combatant_id(opp)
			if front > 0:
				out.append(int(front))
			return out

		Attack.Targeting.REVERSE:
			var my_group := ctx.api.get_group(int(ctx.source_id))
			if my_group < 0:
				return out

			var opp := ctx.api.get_opposing_group(my_group)
			var rear := ctx.api.get_rearmost_combatant_id(opp)
			if rear > 0:
				out.append(int(rear))
			return out

		Attack.Targeting.ENEMIES:
			return ctx.api.get_enemies_of(int(ctx.source_id))

		Attack.Targeting.ALL:
			var ids0: Array[int] = ctx.api.get_combatants_in_group(0, false)
			var ids1: Array[int] = ctx.api.get_combatants_in_group(1, false)
			out.append_array(ids0)
			out.append_array(ids1)
			return out

	return out


static func _is_single(ctx: TargetingContext) -> bool:
	if !ctx.explicit_target_ids.is_empty():
		return ctx.explicit_target_ids.size() == 1
	var target_type := int(ctx.target_type)
	return target_type == Attack.Targeting.STANDARD or target_type == Attack.Targeting.REVERSE


static func _run_stage(ctx: TargetingContext, stage: int) -> void:
	if ctx == null or ctx.api == null:
		return

	ctx.current_stage = int(stage)
	var participants := _collect_participants(ctx, stage)
	participants.sort_custom(func(a, b) -> bool:
		if int(a.priority) == int(b.priority):
			return int(a.discovery_index) < int(b.discovery_index)
		return int(a.priority) < int(b.priority)
	)

	for participant: TargetingParticipant in participants:
		if participant == null:
			continue
		if participant.status_proto != null and participant.status_ctx != null:
			match int(stage):
				TargetingContext.Stage.RETARGET:
					participant.status_proto.on_targeting_retarget(participant.status_ctx, ctx)
				TargetingContext.Stage.INTERPOSE:
					participant.status_proto.on_targeting_interpose(participant.status_ctx, ctx)
		elif participant.arcanum_proto != null:
			match int(stage):
				TargetingContext.Stage.RETARGET:
					participant.arcanum_proto.on_targeting_retarget(ctx.api, ctx)
				TargetingContext.Stage.INTERPOSE:
					participant.arcanum_proto.on_targeting_interpose(ctx.api, ctx)


static func _finalize_targets(ctx: TargetingContext) -> void:
	ctx.current_stage = int(TargetingContext.Stage.FINALIZE)
	var out: Array[int] = []
	for tid in ctx.working_target_ids:
		var target_id := int(tid)
		if target_id <= 0 or !ctx.api.is_alive(target_id):
			continue
		if out.has(target_id):
			continue
		out.append(target_id)
	ctx.final_target_ids = out


static func _collect_participants(ctx: TargetingContext, stage: int) -> Array[TargetingParticipant]:
	var out: Array[TargetingParticipant] = []
	var discovery_index := 0

	discovery_index = _append_status_participants(out, ctx, int(ctx.source_id), stage, discovery_index)
	discovery_index = _append_arcana_participants(out, ctx, int(ctx.source_group_index), stage, discovery_index)

	var defender_ids := ctx.api.get_combatants_in_group(int(ctx.defending_group_index), false)
	for defender_id in defender_ids:
		discovery_index = _append_status_participants(out, ctx, int(defender_id), stage, discovery_index)

	discovery_index = _append_arcana_participants(out, ctx, int(ctx.defending_group_index), stage, discovery_index)
	return out


static func _append_status_participants(
	out: Array[TargetingParticipant],
	ctx: TargetingContext,
	owner_id: int,
	stage: int,
	discovery_index: int
) -> int:
	if ctx.api == null or ctx.api.state == null:
		return discovery_index

	for status_ctx: SimStatusContext in SimStatusSystem.get_effective_status_contexts_for_unit(ctx.api, int(owner_id)):
		if status_ctx == null or !status_ctx.is_valid():
			continue
		var proto := status_ctx.proto
		if proto == null:
			continue

		var participant := TargetingParticipant.new()
		participant.priority = int(proto.get_targeting_priority(stage))
		participant.discovery_index = discovery_index
		participant.status_ctx = status_ctx
		participant.status_proto = proto
		out.append(participant)
		discovery_index += 1

	return discovery_index


static func _append_arcana_participants(
	out: Array[TargetingParticipant],
	ctx: TargetingContext,
	side_group_index: int,
	stage: int,
	discovery_index: int
) -> int:
	if ctx.api == null or ctx.api.state == null or ctx.api.state.arcana == null or ctx.api.state.arcana_catalog == null:
		return discovery_index
	if int(side_group_index) != int(SimBattleAPI.FRIENDLY):
		return discovery_index

	for entry: ArcanaState.ArcanumEntry in ctx.api.state.arcana.list:
		if entry == null or entry.id == &"":
			continue
		var proto: Arcanum = ctx.api.state.arcana_catalog.get_proto(entry.id)
		if proto == null:
			continue

		var participant := TargetingParticipant.new()
		participant.priority = int(proto.get_targeting_priority(stage))
		participant.discovery_index = discovery_index
		participant.arcanum_proto = proto
		out.append(participant)
		discovery_index += 1

	return discovery_index
