# status_effect.gd

class_name StatusEffect
extends Effect

var status: Status

func execute(_api: BattleAPI) -> void:
	SFXPlayer.play(sound)
	for target in targets:
		if !target:
			continue
		if target is Fighter:
			StatusRuntime.apply_status_to_fighter(target, status)
