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

# These two member variables should be clear except when the action is running,
# which is from perform() -> _finish_action(). This is to keep the action
# pseudo-stateless. State should live on NPCAIBehavior.
var remaining_effect_packages: Array[NPCEffectPackage]
var current_ctx: NPCAIContext

# Whether this action can currently be taken
func is_performable(ctx: NPCAIContext) -> bool:
	for model in performable_models:
		if !model.is_performable(ctx):
			return false
	return true


# --- Effect package pipeline ---


func perform(ctx: NPCAIContext) -> void:
	current_ctx = ctx
	remaining_effect_packages = effect_packages.duplicate()

	# Action-level state models (once)
	for m in state_models:
		m.change_state(ctx)

	_next_effect_package()

func _next_effect_package() -> void:
	if remaining_effect_packages.is_empty():
		_finish_action()
		return

	var pkg : NPCEffectPackage = remaining_effect_packages.pop_front()

	# Clear per-effect params
	current_ctx.params.clear()

	# Package-level state models (persistent state)
	for m in pkg.state_models:
		m.change_state(current_ctx)

	# Package-level param models (ephemeral)
	for m in pkg.param_models:
		m.change_params(current_ctx)

	# Execute orchestration sequence
	_execute_effect_sequence(pkg, current_ctx)
	#pkg.effect.execute(current_ctx)

func _execute_effect_sequence(pkg: NPCEffectPackage, ctx: NPCAIContext) -> void:
	if pkg.effect:
		pkg.effect.execute(
			ctx,
			Callable(self, "_on_sequence_done")
		)
	else:
		_on_sequence_done()

func _on_sequence_done() -> void:
	_next_effect_package()

func _finish_action() -> void:
	current_ctx.combatant.resolve_action()
	current_ctx = null

func _change_state(models: Array[StateModel], ctx: NPCAIContext) -> void:
	for m in models:
		if m:
			m.change_state(ctx)

# Called when showing intent
func get_intent_data(ctx: NPCAIContext) -> IntentData:
	var intent := IntentData.new()
	intent.icon = intent_icon
	intent.base_text = _format_intent_text(ctx)
	intent.tooltip = get_tooltip(ctx)
	return intent



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
