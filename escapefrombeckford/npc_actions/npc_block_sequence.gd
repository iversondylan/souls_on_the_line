# npc_block_sequence.gd
class_name NPCBlockSequence extends NPCEffectSequence

@export var sound: Sound


func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	var fighter := ctx.combatant
	if !fighter:
		on_done.call()
		return

	# Decode semantic parameter with default
	var armor := int(ctx.params.get(NPCKeys.ARMOR_AMOUNT, 1))

	# Defensive: non-positive armor does nothing
	if armor <= 0:
		on_done.call()
		return

	# Apply block immediately (no movement, no sequencing)
	var block_effect := BlockEffect.new()
	block_effect.targets = [fighter]
	block_effect.n_armor = armor
	block_effect.sound = sound
	block_effect.execute()

	# Restore info visibility just in case (mirrors attack end semantics)
	fighter.info_visible(true)

	on_done.call()
