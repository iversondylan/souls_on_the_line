# damage_effect.gd
class_name DamageEffect extends Effect

var n_damage: int = 0
var source: Fighter = null
var modifier_type: Modifier.Type #CURRENTLY UNUSED, but function should
# be restored so that there can be damage that does not get modified
# or perhaps damage types with particular weakness/resistance

func execute() -> void:
	for target in targets:
		if !target:
			continue
		var ctx := DamageContext.new(source, target, n_damage)
		target.apply_damage(ctx)
	SFXPlayer.play(sound)
