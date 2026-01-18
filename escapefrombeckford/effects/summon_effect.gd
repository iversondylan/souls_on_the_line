# summon_effect.gd
class_name SummonEffect extends Effect

const SUMMONED_ALLY_SCN := preload("res://scenes/turn_takers/summoned_ally.tscn")

# Fallback for early testing / safety
const DEFAULT_SUMMON_DATA := preload(
	"res://fighters/BasicClone/basic_clone_data.tres"
)

# Required
var battle_scene: BattleScene
var insert_index: int = 0

# Optional inputs
var summon_data: CombatantData
var bound_card_data: CardData   # null means no binding (deplete-style)

# Output (set during execute)
var summoned_fighter: Fighter = null

func execute() -> void:
	if !battle_scene:
		push_warning("SummonEffect.execute() called without battle_scene")
		return

	var summoned_ally: SummonedAlly = SUMMONED_ALLY_SCN.instantiate()
	battle_scene.add_combatant(summoned_ally, 0, insert_index)

	summoned_fighter = summoned_ally

	# --- CombatantData ---
	var data: CombatantData
	if summon_data:
		data = summon_data.duplicate()
	else:
		data = DEFAULT_SUMMON_DATA.duplicate()

	data.init()
	summoned_ally.combatant_data = data

	# --- AI bootstrap ---
	for child in summoned_ally.get_children():
		if child is NPCAIBehavior:
			child.plan_next_intent()
			child.refresh_intent_display_only()

	# --- Optional card binding ---
	if bound_card_data:
		var summon_behavior := summoned_ally.get_node_or_null("SummonedAllyBehavior")
		if summon_behavior:
			summon_behavior.bind_card(bound_card_data)

	# --- Sound ---
	if sound:
		SFXPlayer.play(sound)

func apply_to_card_context(ctx: CardActionContext) -> void:
	if !ctx or !summoned_fighter:
		return

	# Track summoned units
	ctx.summoned_fighters.append(summoned_fighter)

	# Track affected units (for tooltips, triggers, etc.)
	ctx.affected_fighters.append(summoned_fighter)
