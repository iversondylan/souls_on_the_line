# npc_action.gd
class_name NPCAction
extends Resource

enum ChoiceType { CONDITIONAL, CHANCE }

@export var effect_packages: Array[NPCEffectPackage]

@export_group("Selection")
@export var choice_type: ChoiceType = ChoiceType.CHANCE
@export var chance_weight: float = 1.0
@export var performable_models: Array[PerformableModel]
@export var state_models: Array[StateModel]

@export_group("Intent")
@export var intent_icon: Texture2D
@export var intent_text_template: String = ""  # e.g. "{dmg}", "2x{dmg}"

@export_group("Resolution Impact")
@export var sound: AudioStream
@export var resolve_delay: float = 0.6


## Whether this action can currently be taken
func is_performable(ctx: NPCAIContext) -> bool:
	for model in performable_models:
		if !model.is_performable(ctx):
			return false
	return true

func _run_effect_package(pkg: NPCEffectPackage, ai_ctx: NPCAIContext) -> void:
	var ctx := NPCAIContext.new()

	# copy stable references
	ctx.combatant = ai_ctx.combatant
	ctx.battle_scene = ai_ctx.battle_scene
	ctx.rng = ai_ctx.rng
	ctx.state = ai_ctx.state      # shared persistent AI state

	# per-effect fields
	ctx.params = {}
	ctx.preview = ai_ctx.preview

	for model in pkg.models:
		model.apply(ctx)

	pkg.effect.execute(ctx)

## Called when showing intent
func get_intent_data(ctx: NPCAIContext) -> IntentData:
	var intent := IntentData.new()
	intent.icon = intent_icon
	intent.base_text = _format_intent_text(ctx)
	intent.tooltip = get_tooltip(ctx)
	return intent


## Execute the action
## MUST eventually call ctx.combatant.resolve_action()
func perform(ctx: NPCAIContext) -> void:
	#_execute(ctx)  # subclass-specific (attack, block, etc.)

	for model in state_models:
		model.on_perform(ctx)

	resolve_after_delay(ctx)


func resolve_after_delay(ctx: NPCAIContext) -> void:
	var fighter := ctx.combatant
	if !fighter:
		return
	
	if resolve_delay > 0.0:
		fighter.get_tree().create_timer(resolve_delay, false).timeout.connect(
			func():
				fighter.resolve_action()
		)
	else:
		fighter.resolve_action()

## Optional tooltip
func get_tooltip(_ctx: NPCAIContext) -> String:
	return ""


## Optional persistent state
func save_state(_ctx: NPCAIContext) -> Dictionary:
	return {}


func load_state(_ctx: NPCAIContext, _data: Dictionary) -> void:
	pass

func _format_intent_text(ctx: NPCAIContext) -> String:
	if intent_text_template == "":
		return ""

	var values := get_intent_values(ctx)
	var text := intent_text_template
	for k in values.keys():
		text = text.replace("{" + k + "}", str(values[k]))
	return text


## Override if you want dynamic numbers
func get_intent_values(_ctx: NPCAIContext) -> Dictionary:
	return {}

func get_state(ctx: NPCAIContext) -> Dictionary:
	return ctx.state


func get_chance_weight() -> float:
	# Base authored weight
	var weight := chance_weight

	# Read AI state
	var state : Dictionary = get_meta("ai_state") if has_meta("ai_state") else {}

	# Hard disable always wins
	if state.get(NPCKeys.CHANCE_DISABLED, false):
		return 0.0

	# Additive modifier
	weight += float(state.get(NPCKeys.CHANCE_ADD, 0.0))

	# Multiplicative modifier
	weight *= float(state.get(NPCKeys.CHANCE_MULT, 1.0))

	# Clamp for safety
	if weight < 0.0:
		return 0.0

	return weight
