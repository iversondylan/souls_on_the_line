# meta-name: Effect
# meta-description: Create an effect which can be applied to a target.
class_name MyNewEffect
extends Effect

var n_damage: int = 0

func execute(targets: Array[Fighter]) -> void:
	for target in targets:
		if !target:
			continue
		target.take_damage(n_damage, Modifier.Type.DMG_TAKEN)
		SFXPlayer.play(sound)
