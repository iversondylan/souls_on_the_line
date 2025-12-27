# npc_action_def.gd
class_name NPCActionDef extends Resource

enum ChoiceType { CONDITIONAL, CHANCE }
@export var choice_type: ChoiceType = ChoiceType.CHANCE
@export var chance_weight: float = 1.0

@export var intent_icon: Texture2D
@export var intent_text_template: String = "" # e.g. "{dmg}" or "2x{dmg}"

func is_performable(ctx: NPCAIContext) -> bool:
	return true

func get_intent(ctx: NPCAIContext) -> IntentData:
	var id := IntentData.new()
	# fill it from template + ctx (or override per action type)
	return id

func perform(ctx: NPCAIContext) -> void:
	pass
