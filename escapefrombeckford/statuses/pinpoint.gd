class_name PinpointStatus extends Status

const MODIFIER := 0.5

func apply_status(_target: Node) -> void:
	print("%s should take %s%% more damage." % [_target, MODIFIER*100])
	
	var damage_effect := DamageEffect.new()
	damage_effect.n_damage = 12
	damage_effect.execute([_target])
	
	status_applied.emit(self)
	
