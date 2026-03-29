# npc_summon_sequence.gd
class_name NPCSummonSequence
extends NPCEffectSequence

const MAX_UNITS_PER_GROUP := 7

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast):
		return
	if ctx.api == null:
		push_warning("npc_summon_sequence.gd execute(): missing api")
		return

	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("npc_summon_sequence.gd execute(): missing runtime")
		return

	var params: Dictionary = ctx.params if ctx.params else {}
	var actor_id := int(ctx.cid)
	var source_id := int(params.get(Keys.SOURCE_ID, actor_id))
	if source_id <= 0:
		source_id = actor_id
	var group_index := clampi(int(params.get(Keys.GROUP_INDEX, ctx.api.get_group(source_id))), 0, 1)
	var insert_index := int(params.get(Keys.INSERT_INDEX, 0))
	var count := int(params.get(Keys.SUMMON_COUNT, 1))
	if count <= 0:
		return

	var summon_data_orig: CombatantData = _resolve_summon_data(params.get(Keys.SUMMON_DATA, null))
	if summon_data_orig == null:
		push_warning("npc_summon_sequence.gd execute(): missing summon_data")
		return

	var n_existing := ctx.api.get_combatants_in_group(group_index, false).size()
	if n_existing >= MAX_UNITS_PER_GROUP:
		return
	if n_existing + count > MAX_UNITS_PER_GROUP:
		count = MAX_UNITS_PER_GROUP - n_existing
		if count <= 0:
			return

	for _i in range(count):
		var cur_n := ctx.api.get_combatants_in_group(group_index, false).size()
		var idx := clampi(insert_index, 0, cur_n)
		var summon_ctx := SummonContext.new()
		summon_ctx.actor_id = actor_id
		summon_ctx.source_id = source_id
		summon_ctx.group_index = group_index
		summon_ctx.insert_index = idx
		summon_ctx.summon_data = summon_data_orig.duplicate(true) as CombatantData
		summon_ctx.reason = "npc_summon_action"
		runtime.run_summon_action(summon_ctx)

func _resolve_summon_data(value) -> CombatantData:
	if value == null:
		return null
	if value is CombatantData:
		return value
	if value is String:
		var path := str(value)
		if path.is_empty():
			return null
		var res := load(path)
		return res if res is CombatantData else null
	return null
