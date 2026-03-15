# heal_effect.gd
class_name HealEffect extends Effect

var flat_amount: int = 0
var of_total: float = 0.0
var of_missing: float = 0.0
var source: Fighter = null

#func execute(api: BattleAPI) -> void:
	#if sound:
		#api.play_sfx(sound) # preferred, keeps shim consistent
#
	#for target: Fighter in targets:
		#if !target:
			#continue
#
		#var ctx := HealContext.new(source, target, flat_amount, of_total, of_missing)
#
		## ensure ids early (helps sim + robustness)
		#if source and ctx.source_id == 0:
			#ctx.source_id = source.combat_id
		#if target and ctx.target_id == 0:
			#ctx.target_id = target.combat_id
#
		#api.resolve_heal(ctx)
