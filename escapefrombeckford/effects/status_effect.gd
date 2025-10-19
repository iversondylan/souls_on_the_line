class_name StatusEffect
extends Effect

var status: Status

func execute(targets: Array[Fighter]) -> void:
	for target in targets:
		if !target:
			continue
		if target is Fighter:
			target.combatant.status_grid.add_status(status)
	SFXPlayer.play(sound)
