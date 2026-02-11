# heal_effect.gd
class_name HealEffect extends Effect

var flat_amount: int = 0
var of_total: float = 0.0
var of_missing: float = 0.0

var source: Fighter = null

func execute(_api: BattleAPI) -> void:
	for target: Fighter in targets:
		if !target:
			continue
		var ctx := HealContext.new(source, target, flat_amount, of_total, of_missing)
		target.apply_heal(ctx)
	SFXPlayer.play(sound)
