# summon_action.gd
class_name SummonAction extends CardAction

@export var summon_data: CombatantData
@export var sound: Sound = load("res://audio/summon_zap.tres")

func activate_sim(ctx: CardActionContextSim) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var insert_index := ctx.resolved.insert_index
	if insert_index < 0:
		insert_index = 0

	var sctx := SummonContext.new()
	sctx.group_index = 0
	sctx.insert_index = insert_index
	sctx.source_id = int(ctx.source_id)
	sctx.summon_data = _build_clone_data_sim()
	sctx.mortality = CombatantView.Mortality.SOULBOUND

	# NEW: bind summon reserve to this summoned unit
	if ctx.card_data != null and !ctx.card_data.deplete:
		ctx.card_data.ensure_uid()
		sctx.bound_card_uid = String(ctx.card_data.uid)

	# (keep your windup snapshot threading too)
	if ctx.params != null and ctx.params.has(Keys.WINDUP_ORDER_IDS):
		var snap = ctx.params[Keys.WINDUP_ORDER_IDS]
		if snap is PackedInt32Array:
			sctx.windup_order_ids = snap

	ctx.api.summon(sctx)

	if sctx.summoned_id > 0:
		ctx.summoned_ids.append(sctx.summoned_id)
	return true

func _build_clone_data_sim() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data

#func _build_clone_data(ctx: CardActionContext) -> CombatantData:
	#var data := summon_data.duplicate()
	#data.init()
	##
	#return data

func description_arity() -> int:
	return 3

func get_preview_summon_data() -> CombatantData:
	print("summon_action.gd get_preview_summon_data()")
	return summon_data

#func get_description_values(ctx: CardActionContext) -> Array:
	#var data := summon_data.duplicate()
	#data.init()
	#var params := CombatForecast.preview_action_params(summon_data)
	#var dmg := int(params.get(Keys.DAMAGE, 0))
	#return [dmg, summon_data.max_health, summon_data.name]

func requires_summon_slot() -> bool:
	return true
