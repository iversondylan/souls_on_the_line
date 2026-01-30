# summon_action.gd
class_name SummonAction extends CardAction

@export var summon_data: CombatantData
@export var sound: Sound = load("res://audio/summon_zap.tres")

func build_effect(ctx: CardActionContext) -> SummonEffect:
	var effect := SummonEffect.new()
	effect.battle_scene = ctx.battle_scene
	effect.insert_index = ctx.resolved_target.insert_index
	effect.summon_data = _build_clone_data(ctx)
	effect.sound = sound
	if ctx.card_data and not ctx.card_data.deplete:
		effect.bound_card_data = ctx.card_data
	return effect

func activate(ctx: CardActionContext) -> bool:
	if !ctx.battle_scene or !ctx.resolved_target:
		return false
	var effect := build_effect(ctx)
	effect.execute()
	effect.apply_to_card_context(ctx)
	return true


func _build_clone_data(ctx: CardActionContext) -> CombatantData:
	var data := summon_data.duplicate()
	data.init()
	
	# Spectral clones inherit mana caps from player
	if ctx.player and ctx.player.combatant_data:
		data.max_mana_red = ctx.player.combatant_data.max_mana_red
		data.max_mana_green = ctx.player.combatant_data.max_mana_green
		data.max_mana_blue = ctx.player.combatant_data.max_mana_blue
	
	return data

func description_arity() -> int:
	return 3

func get_description_values(ctx: CardActionContext) -> Array:
	var data := summon_data.duplicate()
	data.init()
	if ctx.player and ctx.player.combatant_data:
		data.max_mana_red = ctx.player.combatant_data.max_mana_red
		data.max_mana_green = ctx.player.combatant_data.max_mana_green
		data.max_mana_blue = ctx.player.combatant_data.max_mana_blue
	var params := CombatForecast.preview_action_params(summon_data)
	var dmg := int(params.get(NPCKeys.DAMAGE, 0))
	return [dmg, summon_data.max_health, summon_data.name]

func requires_summon_slot() -> bool:
	return true
