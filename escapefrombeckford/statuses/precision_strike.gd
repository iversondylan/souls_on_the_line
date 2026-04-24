class_name PrecisionStrikeStatus extends Status

const ID := &"precision_strike"

func get_id() -> StringName:
	return ID

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	if ctx == null or ctx.api == null:
		return []

	var owner_id := int(ctx.owner_id)
	if owner_id <= 0:
		return []

	var group_index := int(ctx.api.get_group(owner_id))
	if group_index < 0:
		return []

	var order := ctx.api.get_combatants_in_group(group_index, false)
	var rank := -1
	for i in range(order.size()):
		if int(order[i]) == owner_id:
			rank = i
			break
	if rank <= 0:
		return []

	var bonus_damage := maxi(int(ctx.stacks), 0) * rank
	if bonus_damage <= 0:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.flat_value = bonus_damage
	token.mult_value = 0.0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.tags = [String(ID)]
	Status.set_token_owner(token, ctx)
	return [token]

func get_tooltip(stacks: int = 0) -> String:
	return "Precision Strike: deal +%s damage for each space behind the front." % stacks
