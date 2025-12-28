# emergency_block_action.gd
class_name EmergencyBlockAction extends NPCAction

@export var armor_amount: int = 15
@export var hp_threshold: int = 5

func is_performable(ctx: NPCAIContext) -> bool:
	if ctx.state.get("used", false):
		return false
	return ctx.combatant.combatant_data.health <= hp_threshold

func perform(ctx: NPCAIContext) -> void:
	var fighter := ctx.combatant
	if !fighter:
		fighter.resolve_action()
		return

	var block := BlockEffect.new()
	block.targets = [fighter]
	block.n_armor = armor_amount
	block.sound = sound
	block.execute()

	ctx.state["used"] = true
	fighter.resolve_action()

func save_state(ctx: NPCAIContext) -> Dictionary:
	return { "used": ctx.state.get("used", false) }

func load_state(ctx: NPCAIContext, data: Dictionary) -> void:
	ctx.state["used"] = data.get("used", false)
