class_name DamageEffect extends Effect

var n_damage: int = 0
var modifier_type := Modifier.Type.DMG_TAKEN

func execute(targets: Array[Fighter]) -> void:
	for target in targets:
		if !target:
			continue
		target.take_damage(n_damage, modifier_type)
		SFXPlayer.play(sound)
