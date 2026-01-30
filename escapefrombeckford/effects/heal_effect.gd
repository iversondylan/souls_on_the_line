# heal_effect.gd
class_name HealEffect extends Effect

var heal_amount: int = 0
var source: Fighter = null

func execute() -> void:
	for target in targets:
		if !target:
			continue
		var ctx := DamageContext.new(source, target, n_damage)
		target.apply_damage(ctx)
	SFXPlayer.play(sound)
