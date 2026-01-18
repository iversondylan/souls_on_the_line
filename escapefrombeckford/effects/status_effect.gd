class_name StatusEffect
extends Effect

var status: Status

func execute() -> void:
	SFXPlayer.play(sound)#, -6.0)
	for target in targets:
		if !target:
			continue
		if target is Fighter:
			target.combatant.status_grid.add_status(status)
