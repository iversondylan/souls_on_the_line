# sim_summon_runner.gd

class_name SimSummonRunner extends RefCounted

const MAX_UNITS_PER_GROUP := 7

static func run(api: SimBattleAPI, ctx: NPCAIContext) -> void:
	if api == null or api.state == null or ctx == null:
		return
	if bool(ctx.forecast):
		return

	var params: Dictionary = ctx.params if ctx.params else {}

	var actor_id := int(ctx.cid)
	if actor_id <= 0:
		return

	var source_id := int(params.get(Keys.SOURCE_ID, actor_id))
	if source_id <= 0:
		source_id = actor_id

	var group_index := int(params.get(Keys.GROUP_INDEX, api.get_group(source_id)))
	group_index = clampi(group_index, 0, 1)

	var insert_index := int(params.get(Keys.INSERT_INDEX, 0))
	var count := int(params.get(Keys.SUMMON_COUNT, 1))
	if count <= 0:
		return

	# Resolve summon data (whatever your convention is)
	var summon_data_orig: CombatantData = _resolve_summon_data(
		params.get(Keys.SUMMON_DATA, null)
	)
	if summon_data_orig == null:
		push_warning("SimSummonRunner: missing summon_data")
		return

	# Capacity check
	var n_existing := api.get_combatants_in_group(group_index, false).size()
	if n_existing >= MAX_UNITS_PER_GROUP:
		return
	if n_existing + count > MAX_UNITS_PER_GROUP:
		count = MAX_UNITS_PER_GROUP - n_existing
		if count <= 0:
			return

	# ---- NEW: action scope ----
	if api.writer != null:
		api.writer.scope_begin(
			Scope.Kind.SUMMON_ACTION,
			"count=%d g=%d idx=%d" % [count, group_index, insert_index],
			actor_id,
			{
				Keys.ACTOR_ID: int(actor_id),
				Keys.SOURCE_ID: int(source_id),
				Keys.GROUP_INDEX: int(group_index),
				Keys.INSERT_INDEX: int(insert_index),
				Keys.SUMMON_COUNT: int(count),
				Keys.PROTO: String(summon_data_orig.resource_path),
			}
		)

	for i in range(count):
		var cur_n := api.get_combatants_in_group(group_index, false).size()
		var idx := clampi(insert_index, 0, cur_n)

		var sc := SummonContext.new()
		sc.source_id = source_id
		sc.group_index = group_index
		sc.insert_index = idx

		var cd := summon_data_orig.duplicate(true) as CombatantData
		if cd != null:
			cd.init()
		sc.summon_data = cd

		api.summon(sc)

	if api.writer != null:
		api.writer.scope_end()


static func _resolve_summon_data(value) -> CombatantData:
	if value == null:
		return null
	if value is CombatantData:
		return value
	if value is String:
		var path := String(value)
		if path.is_empty():
			return null
		var res := load(path)
		return res if res is CombatantData else null
	return null
