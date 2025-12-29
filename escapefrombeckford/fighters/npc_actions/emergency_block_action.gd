# emergency_block_action.gd
class_name EmergencyBlockAction extends NPCAction

@export var armor_amount: int = 15
@export var hp_threshold: int = 5
#@export var resolve_delay: float = 0.6

func is_performable(ctx: NPCAIContext) -> bool:
	if ctx.state.get("used", false):
		return false
	return ctx.combatant.combatant_data.health <= hp_threshold

func perform(ctx: NPCAIContext) -> void:
	ctx.combatant.intent_container.clear_display()
	var fighter := ctx.combatant
	if !fighter:
		return

	var block := BlockEffect.new()
	block.targets = [fighter]
	block.n_armor = armor_amount
	block.sound = sound
	block.execute()

	ctx.state["used"] = true
	resolve_after_delay(ctx)

func get_intent_values(_ctx: NPCAIContext) -> Dictionary:
	return { "armor": armor_amount }

func save_state(ctx: NPCAIContext) -> Dictionary:
	return { "used": ctx.state.get("used", false) }

func load_state(ctx: NPCAIContext, data: Dictionary) -> void:
	ctx.state["used"] = data.get("used", false)
