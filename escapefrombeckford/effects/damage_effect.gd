# damage_effect.gd
class_name DamageEffect extends Effect

var n_damage: int = 0
var source: Fighter = null
var modifier_type: Modifier.Type

func execute(api: BattleAPI) -> void:
	if !api:
		return

	for target in targets:
		if !target:
			continue

		var ctx := DamageContext.new(source, target, n_damage)
		ctx.api = api

		# Populate ids so sim can work later, and live can survive freed nodes.
		if source:
			ctx.source_id = source.combat_id
		if target:
			ctx.target_id = target.combat_id

		api.resolve_damage(ctx)

	api.play_sfx(sound)



## damage_effect.gd
#class_name DamageEffect extends Effect
#
#var n_damage: int = 0
#var source: Fighter = null
#var modifier_type: Modifier.Type #CURRENTLY UNUSED, but function should
## be restored so that there can be damage that does not get modified
## or perhaps damage types with particular weakness/resistance
#
#func execute(api: BattleAPI) -> void:
	#if !api:
		#return
#
	#for target in targets:
		#if !target:
			#continue
		#var ctx := DamageContext.new(source, target, n_damage)
		#api.resolve_damage(ctx)
#
	#api.play_sfx(sound)
