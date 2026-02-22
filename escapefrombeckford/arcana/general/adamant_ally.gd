# adamant_ally.gd

extends Arcanum

const ID := &"adamant_ally"

@export var summon_data: CombatantData

func get_id() -> StringName:
	return ID

func activate_arcanum(ctx: ArcanumContext) -> Variant:
	if !summon_data or !ctx:
		push_warning("adamant_ally.gd error: no summon_data or ctx")
		return
	if !ctx.battle_scene or !ctx.player:
		push_warning("adamant_ally.gd error: no battle_scene or player")
		return

	var effect := build_effect(ctx)
	effect.execute(ctx.api)
	return null

func build_effect(ctx: ArcanumContext) -> SummonEffect:
	var effect := SummonEffect.new()
	#effect.battle_scene = ctx.battle_scene
	effect.insert_index = ctx.player.get_index()
	effect.summon_data = _build_summon_data()
	return effect

func _build_summon_data() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data
