# npc_summon_sequence.gd
class_name NPCSummonSequence
extends NPCEffectSequence

const MAX_UNITS_PER_GROUP := 7

func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	if !ctx:
		on_done.call()
		return
	
	if bool(ctx.forecast):
		on_done.call()
		return
	
	if !ctx.api:
		push_warning("NPCSummonSequence: missing ctx.api")
		on_done.call()
		return
	
	var params: Dictionary = ctx.params if ctx.params else {}
	
	var group_index := int(params.get(Keys.GROUP_INDEX, 0))
	var insert_index := int(params.get(Keys.INSERT_INDEX, 0))
	var count := int(params.get(Keys.SUMMON_COUNT, 1))
	group_index = clampi(group_index, 0, 1)
	
	if count <= 0:
		on_done.call()
		return
	
	var summon_data_orig: CombatantData = _resolve_summon_data(
		params.get(Keys.SUMMON_DATA, load(SummonEffect.DEFAULT_SUMMON_DATA))
	)
	var summon_sound : Sound = params.get(Keys.SUMMON_SOUND, null)
	
	# Capacity check via API
	var n_existing := ctx.api.get_n_combatants_in_group(group_index, false)
	if n_existing >= MAX_UNITS_PER_GROUP:
		on_done.call()
		return
	if n_existing + count > MAX_UNITS_PER_GROUP:
		on_done.call()
		return
	
	for i in range(count):
		var cur_n := ctx.api.get_n_combatants_in_group(group_index, false)
		var idx := clampi(insert_index, 0, cur_n)
	
		var effect := SummonEffect.new()
		effect.group_index = group_index
		effect.insert_index = idx
	
		if summon_data_orig:
			effect.summon_data = summon_data_orig.duplicate()
		if summon_sound:
			effect.sound = summon_sound
	
		effect.execute(ctx.api)
	
	on_done.call()

#func _resolve_summon_data(value) -> CombatantData:
	#if value == null:
		#return null
	#if value is CombatantData:
		#return value
	#if value is String:
		#var path := str(value)
		#if path.is_empty():
			#return null
		#var res := load(path)
		#return res if res is CombatantData else null
	#return null

# -------------------------
# SIM IMPLEMENTATION
# -------------------------
func execute_sim(ctx: NPCAIContext) -> void:
	if ctx == null or bool(ctx.forecast):
		return
	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("NPCSummonSequence.execute_sim: missing runtime")
		return
	runtime.run_summon_action(ctx)

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
