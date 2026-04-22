class_name VulnerableAuraStatus extends Aura

const ID := &"vulnerable_aura"

func get_id() -> StringName:
	return ID

func get_tooltip(stacks: int = 0) -> String:
	if stacks <= 1:
		return "All opponents are Vulnerable. Ticks down at the end of this unit's turns."
	return "All opponents are Vulnerable for %s more of this unit's turns." % str(stacks)
