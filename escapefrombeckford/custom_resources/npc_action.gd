# npc_action.gd
class_name NPCAction extends Resource

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


# --- Effect package pipeline ---

func _change_state(models: Array[StateModel], ctx: NPCAIContext) -> void:
	for m in models:
		if m:
			m.change_state(ctx)

func _make_effect_context(ai_ctx: NPCAIContext) -> NPCAIContext:
	var ctx := NPCAIContext.new()

	# stable references (shared)
	ctx.combatant = ai_ctx.combatant
	ctx.battle_scene = ai_ctx.battle_scene
	ctx.rng = ai_ctx.rng
	ctx.state = ai_ctx.state          # IMPORTANT: shared persistent state

	# per-effect fields (fresh)
	ctx.params = {}
	ctx.preview = ai_ctx.preview

	return ctx

func _execute_effect_sequence(pkg: NPCEffectPackage, eff_ctx: NPCAIContext) -> void:
	# 1) param models populate eff_ctx.params
	for m in pkg.param_models:
		if m:
			m.change_params(eff_ctx)

	# 2) execute the orchestration sequence
	if pkg.effect:
		pkg.effect.execute(eff_ctx)

func _run_effect_package(pkg: NPCEffectPackage, ai_ctx: NPCAIContext) -> void:
	# A) state models first, mutating shared ai_ctx.state
	_change_state(state_models, ai_ctx)
	_change_state(pkg.state_models, ai_ctx)

	# B) build fresh per-effect context (shares ai_ctx.state but fresh params)
	var eff_ctx := _make_effect_context(ai_ctx)

	# C) run effect sequence
	_execute_effect_sequence(pkg, eff_ctx)

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


func get_chance_weight(ctx: NPCAIContext) -> float:
	var weight := chance_weight
	var state := ctx.state if ctx and ctx.state else {}

	if state.get(NPCKeys.CHANCE_DISABLED, false):
		return 0.0

	weight += float(state.get(NPCKeys.CHANCE_ADD, 0.0))
	weight *= float(state.get(NPCKeys.CHANCE_MULT, 1.0))

	return maxf(weight, 0.0)
