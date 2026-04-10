# alacrity.gd

class_name AlacrityStatus extends Status

const ID := &"alacrity"

func get_id() -> StringName:
	return ID

func on_attack_will_run(_ctx: SimStatusContext, attack_ctx: AttackContext) -> void:
	if attack_ctx == null:
		return
	attack_ctx.strikes = maxi(int(attack_ctx.strikes), 1) + 1

func get_tooltip(_intensity: int = 0, duration: int = 0) -> String:
	if duration == 1:
		return "Alacrity: attacks get +1 strike for 1 turn."
	return "Alacrity: attacks get +1 strike for %s turns." % duration
