class_name BuffEffect
extends Effect

#var n_damage: int = 0

func execute(targets: Array[Fighter]) -> void:
	for target in targets:
		if !target:
			continue
		#target.take_damage(n_damage)
		SFXPlayer.play(sound)
