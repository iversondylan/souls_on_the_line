class_name ResonanceSpikeStatus extends Aura

const ID := "resonance_spike"

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_modifier_tokens() -> Array[ModifierToken]:
	if is_expired():
		print("resonance_spike_status.gd is expired but tokens requested")
		return []
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = intensity
	token.mult_value = 0.0
	token.source_id = ID
	token.owner = status_parent
	
	token.scope = ModifierToken.Scope.TARGET
	token.tags = [
		Aura.AURA_SECONDARY_FLAG,
		Aura.AURA_ALLIES
	]
	
	return [token]

func get_tooltip() -> String:
	return "Resonance Spike [Aura]: Allies deal +%s damage until the start of this unit’s next turn." % intensity
