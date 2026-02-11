extends Arcanum

#const ID := "sigil_of_mana"

@export var summon_data: CombatantData

func activate_arcanum(ctx: ArcanumContext) -> void:
	if !summon_data or !ctx:
		push_warning("adamant_ally.gd error: no summon_data or ctx")
		return
	ctx.battle_scene = ctx.arcanum_display.get_tree().get_first_node_in_group("battle_scene")
	ctx.player = ctx.arcanum_display.get_tree().get_first_node_in_group("player")
	if !ctx.battle_scene or !ctx.player:
		push_warning("adamant_ally.gd error: no battle_scene or player")
		return
	var effect := build_effect(ctx)
	effect.execute(ctx.api)

func build_effect(ctx: ArcanumContext) -> SummonEffect:
	var effect := SummonEffect.new()
	effect.battle_scene = ctx.battle_scene
	effect.insert_index = ctx.player.get_index()
	effect.summon_data = _build_summon_data()
	return effect

func _build_summon_data() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data
