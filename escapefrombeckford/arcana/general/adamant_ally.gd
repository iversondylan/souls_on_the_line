# adamant_ally.gd

extends Arcanum
const ID := &"adamant_ally"
@export var summon_data: CombatantData

func get_id() -> StringName:
	return ID

func activate_arcanum(ctx: ArcanumContext) -> Variant:
	if !summon_data or !ctx:
		push_warning("adamant_ally.gd error: no summon_data or ctx")
		return null
	if !ctx.api:
		push_warning("adamant_ally.gd error: no api")
		return null

	# LIVE PATH (unchanged)
	if ctx.battle_scene and ctx.player:
		var effect := build_effect_live(ctx)
		effect.execute(ctx.api)
		return null

	# SIM PATH
	var player_id := int(ctx.params.get(&"player_id", 0))
	if player_id <= 0:
		push_warning("adamant_ally.gd sim error: missing ctx.params[player_id]")
		return null

	var effect := build_effect_sim(ctx, player_id)
	effect.execute(ctx.api)
	return null


func build_effect_live(ctx: ArcanumContext) -> SummonEffect:
	var effect := SummonEffect.new()
	effect.group_index = 0
	effect.insert_index = ctx.player.get_index()
	effect.summon_data = _build_summon_data()
	return effect

func build_effect_sim(ctx: ArcanumContext, player_id: int) -> SummonEffect:
	var effect := SummonEffect.new()

	# default: summon into friendly group
	effect.group_index = int(ctx.params.get(&"group_index", 0))

	# default insert_index: player’s index (requires BattleAPI helper)
	var insert_index := int(ctx.params.get(&"insert_index", -1))
	if insert_index < 0:
		# We can compute from API if it exposes rank; your SimBattleAPI does.
		insert_index = ctx.api.get_rank_in_group(player_id)
		if insert_index < 0:
			insert_index = 0

	effect.insert_index = insert_index
	effect.summon_data = _build_summon_data()
	return effect

func _build_summon_data() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data
