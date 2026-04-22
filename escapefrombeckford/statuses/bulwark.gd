class_name BulwarkStatus extends Status

const ID := &"bulwark"
const MAX_REDUCTION := 75

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_TAKEN]

func get_max_stacks() -> int:
	return MAX_REDUCTION

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if !ctx:
		return []

	var capped_stacks := mini(maxi(int(ctx.stacks), 0), MAX_REDUCTION)
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_TAKEN
	token.mult_value = -0.01 * float(capped_stacks)
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.priority = 0
	token.tags = [ID]
	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(stacks: int = 0) -> String:
	return "Bulwark: take %s%% less damage until your next turn." % mini(maxi(stacks, 0), MAX_REDUCTION)
