# summon_action.gd
class_name SummonAction extends CardAction

@export var summon_data: CombatantData
@export var sound: Sound = load("res://audio/summon_zap.tres")

func build_effect(ctx: CardActionContext) -> SummonEffect:
	var effect := SummonEffect.new()
	#effect.battle_scene = ctx.battle_scene
	effect.insert_index = ctx.resolved_target.insert_index
	effect.summon_data = _build_clone_data(ctx)
	effect.mortality = CombatantView.Mortality.SOULBOUND
	effect.sound = sound
	if ctx.card_data and not ctx.card_data.deplete:
		effect.bound_card_data = ctx.card_data
	return effect

func activate(ctx: CardActionContext) -> bool:
	if !ctx.battle_scene or !ctx.resolved_target:
		return false

	var effect := build_effect(ctx)
	effect.execute(ctx.battle_scene.api)

	# NEW: defer application until later (after runner processes)
	ctx.pending_summon_effects.append(effect)

	return true

func activate_sim(ctx: CardActionContextSim) -> bool:
	if ctx == null or ctx.api == null:
		return false

	# Determine insert index
	var insert_index := ctx.resolved.insert_index
	if insert_index < 0:
		insert_index = 0

	var sctx := SummonContext.new()
	sctx.group_index = 0 # friendly
	sctx.insert_index = insert_index
	sctx.summon_data = _build_clone_data_sim() # same duplicate/init
	sctx.mortality = CombatantView.Mortality.SOULBOUND
	ctx.api.summon(sctx)

	if sctx.summoned_id > 0:
		ctx.summoned_ids.append(sctx.summoned_id)
	return true

func _build_clone_data_sim() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data

func _build_clone_data(ctx: CardActionContext) -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	#
	return data

func description_arity() -> int:
	return 3

func get_description_values(ctx: CardActionContext) -> Array:
	var data := summon_data.duplicate()
	data.init()
	var params := CombatForecast.preview_action_params(summon_data)
	var dmg := int(params.get(Keys.DAMAGE, 0))
	return [dmg, summon_data.max_health, summon_data.name]

func requires_summon_slot() -> bool:
	return true
