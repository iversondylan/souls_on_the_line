class_name StatusEffect
extends Effect

var status: Status

func execute(targets: Array[Fighter]) -> void:
	for target in targets:
		#print("status_effect.gd execute(): there's a target: %s" % target)
		if !target:
			continue
		if target is Fighter:
			target.combatant.status_grid.add_status(status)
	SFXPlayer.play(sound)
