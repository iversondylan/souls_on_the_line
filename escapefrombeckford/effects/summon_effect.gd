# summon_effect.gd
class_name SummonEffect extends Effect

const DEFAULT_SUMMON_DATA := "res://fighters/BasicClone/basic_clone_data.tres"

var group_index: int = 0
var insert_index: int = 0


var summon_data: CombatantData
var bound_card_data: CardData
var mortality: CombatantView.Mortality
var summon_ctx: SummonContext = null

func execute(api: SimBattleAPI) -> void:
	if !api:
		return
	
	summon_ctx = SummonContext.new()
	summon_ctx.group_index = group_index
	summon_ctx.insert_index = insert_index
	summon_ctx.summon_data = summon_data
	summon_ctx.bound_card_data = bound_card_data
	summon_ctx.sfx = sound

	api.summon(summon_ctx)

#func get_summoned_fighter() -> Fighter:
	#return summon_ctx.summoned_fighter if summon_ctx else null

func get_summoned_id() -> int:
	return summon_ctx.summoned_id if summon_ctx else 0

#func apply_to_card_context(ctx: CardActionContext) -> void:
	#if !ctx or !summon_ctx:
		#return
#
	#var f := summon_ctx.summoned_fighter
	#if !f:
		#return
#
	#ctx.summoned_fighters.append(f)
	#ctx.affected_fighters.append(f)
