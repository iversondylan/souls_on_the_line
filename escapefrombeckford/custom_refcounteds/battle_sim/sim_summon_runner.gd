# sim_summon_runner.gd

class_name SimSummonRunner extends RefCounted

const MAX_UNITS_PER_GROUP := 7

static func run(api: SimBattleAPI, ctx: NPCAIContext) -> void:
	if api == null or api.state == null or ctx == null:
		return
	if bool(ctx.forecast):
		return

	var params: Dictionary = ctx.params if ctx.params else {}

	var source_id := int(ParamModel._actor_id(ctx))
	if source_id <= 0:
		source_id = int(ctx.cid)

	var group_index := int(params.get(Keys.GROUP_INDEX, api.get_group(source_id)))
	var insert_index := int(params.get(Keys.INSERT_INDEX, 0))
	var count := int(params.get(Keys.SUMMON_COUNT, 1))
	group_index = clampi(group_index, 0, 1)

	if count <= 0:
		return

	var summon_data_orig: CombatantData = _resolve_summon_data(
		params.get(Keys.SUMMON_DATA, load(SummonEffect.DEFAULT_SUMMON_DATA))
	)
	if summon_data_orig == null:
		push_warning("SimSummonRunner: missing summon_data")
		return

	# Capacity check
	var n_existing := api.get_combatants_in_group(group_index, false).size()
	if n_existing >= MAX_UNITS_PER_GROUP:
		return
	if n_existing + count > MAX_UNITS_PER_GROUP:
		return

	# Beat markers FIRST (summon happens during beat 2)
	if api.writer != null:
		api.writer.emit_summon_windup(source_id, group_index, insert_index, count, {
			Keys.PROTO: String(summon_data_orig.resource_path),
		})
		api.writer.emit_summon_followthrough(source_id, group_index, insert_index, count, {
			Keys.PROTO: String(summon_data_orig.resource_path),
		})

	# Apply summons after followthrough (part of beat 2)
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
