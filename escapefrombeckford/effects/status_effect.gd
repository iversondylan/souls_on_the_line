# status_effect.gd
class_name StatusEffect
extends Effect

var status: Status
var source: Fighter = null # optional, but nice for procs/logging
var duration: int = 0
var intensity: int = 0

func execute(_api: BattleAPI) -> void:
	if !_api:
		return

	_api.play_sfx(sound)

	if !status:
		push_warning("StatusEffect.execute(): status is null")
		return

	for target in targets:
		if !target:
			continue

		var ctx := StatusContext.new()
		ctx.source = source
		ctx.target = target
		ctx.status = status
		ctx.duration = duration
		ctx.intensity = intensity
		ctx.hydrate_ids()

		_api.apply_status(ctx)


## status_effect.gd
#
#class_name StatusEffect
#extends Effect
#
#var status: Status
#
#func execute(_api: BattleAPI) -> void:
	#SFXPlayer.play(sound)
	#for target in targets:
		#if !target:
			#continue
		#if target is Fighter:
			#StatusRuntime.apply_status_to_fighter(target, status)
