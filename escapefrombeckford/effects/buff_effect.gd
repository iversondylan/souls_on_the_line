class_name BuffEffect
extends Effect

#var n_damage: int = 0

func execute() -> void:
	for target in targets:
		if !target:
			continue
		SFXPlayer.play(sound)
