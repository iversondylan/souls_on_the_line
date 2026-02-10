# resonance_spike.gd

class_name ResonanceSpikeStatus extends Aura

const ID := "resonance_spike"

func get_id() -> String:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx or (expiration_policy == ExpirationPolicy.DURATION and duration <= 0):
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = ctx.intensity
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.Scope.TARGET
	token.tags = [
		Aura.AURA_SECONDARY_FLAG,
		Aura.AURA_ALLIES
	]

	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip() -> String:
	return "Resonance Spike [Aura]: Allies deal +%s damage. This effect is lost if stability is broken." % intensity
