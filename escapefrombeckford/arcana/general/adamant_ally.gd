# adamant_ally.gd

extends Arcanum
const ID := &"adamant_ally"
@export var summon_data: CombatantData

func get_id() -> StringName:
	return ID

func on_battle_started(api: SimBattleAPI) -> void:
	if api == null or api.runtime == null or summon_data == null:
		return

	var player_id := int(api.get_player_id())
	if player_id <= 0:
		push_warning("adamant_ally.gd on_battle_started(): missing player_id")
		return

	var summon_ctx := SummonContext.new()
	summon_ctx.actor_id = player_id
	summon_ctx.group_index = SimBattleAPI.FRIENDLY
	summon_ctx.insert_index = maxi(int(api.get_rank_in_group(player_id)), 0)
	summon_ctx.source_id = player_id
	summon_ctx.summon_data = _build_summon_data()
	summon_ctx.mortality = CombatantView.Mortality.SOULBOUND
	summon_ctx.reason = "arcanum_battle_start"
	summon_ctx.origin_arcanum_id = get_id()

	api.runtime.run_summon_action(summon_ctx)

func _build_summon_data() -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	return data

func get_beats() -> int:
	return Beats.IN_OUT
