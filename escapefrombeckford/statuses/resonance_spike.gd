# resonance_spike.gd

class_name ResonanceSpikeStatus extends Aura

const ID := &"resonance_spike"

func get_id() -> StringName:
	return ID

func get_tooltip(stacks: int = 0) -> String:
	return "Resonance Spike: allies deal +%s damage." % stacks
