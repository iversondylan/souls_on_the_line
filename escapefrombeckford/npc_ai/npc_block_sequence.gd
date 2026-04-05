# npc_block_sequence.gd
class_name NPCBlockSequence extends NPCEffectSequence

@export var sound: Sound = preload("uid://gqcqohdssol1")

func execute(ctx: NPCAIContext) -> void:
	if ctx == null or ctx.api == null or ctx.api.state == null:
		push_warning("npc_block_sequence.gd execute(): missing ctx/api/state")
		return

	var actor_id := ctx.get_actor_id()
	if actor_id <= 0:
		push_warning("npc_block_sequence.gd execute(): invalid actor_id")
		return

	var u: CombatantState = ctx.api.state.get_unit(actor_id)
	if u == null or !u.is_alive():
		return

	var params: Dictionary = ctx.params if ctx.params else {}
	var armor_amount := int(params.get(Keys.ARMOR_AMOUNT, 0))
	if armor_amount <= 0:
		return

	u.armor = maxi(int(u.armor) + armor_amount, 0)
