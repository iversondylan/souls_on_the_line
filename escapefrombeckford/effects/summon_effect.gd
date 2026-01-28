# summon_effect.gd
class_name SummonEffect extends Effect

const SUMMONED_ALLY_SCN := preload("res://scenes/turn_takers/summoned_ally.tscn")
const ENEMY_SCN := preload("res://scenes/turn_takers/enemy.tscn")

# Fallback for early testing / safety
const DEFAULT_SUMMON_DATA := preload("res://fighters/BasicClone/basic_clone_data.tres")
const DEFAULT_SUMMON_SOUND := preload("res://audio/summon_zap.tres")

# Required
var battle_scene: BattleScene
var group_index: int = 0   # 0 = friendly, 1 = enemy (by your current convention)
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
	
	# Safety: clamp group + insertion
	group_index = clampi(group_index, 0, 1)
	
	var n_in_group := battle_scene.get_n_combatants_in_group(group_index)
	insert_index = clampi(insert_index, 0, n_in_group)
	
	# Choose which scene to instantiate
	var fighter: Fighter = null
	if group_index == 1:
		fighter = ENEMY_SCN.instantiate()
	else:
		fighter = SUMMONED_ALLY_SCN.instantiate()
	
	if fighter == null:
		push_warning("SummonEffect.execute() failed to instantiate fighter")
		return
	
	# Add to battlefield
	battle_scene.add_combatant(fighter, group_index, insert_index)
	summoned_fighter = fighter
	
	# --- CombatantData ---
	var data: CombatantData = (summon_data if summon_data else DEFAULT_SUMMON_DATA).duplicate()
	data.init()
	fighter.combatant_data = data
	
	# Safety: keep CombatantData.team consistent with group_index if you rely on it
	# (You appear to use battle_group/team elsewhere; this avoids subtle mismatches.)
	fighter.combatant_data.team = group_index
	
	# --- AI bootstrap ---
	for child in fighter.get_children():
		if child is NPCAIBehavior:
			child.plan_next_intent()
			child.refresh_intent_display()
	
	# --- Optional card binding (only makes sense for SummonedAlly) ---
	if bound_card_data:
		if fighter is SummonedAlly:
			var summon_behavior := fighter.get_node_or_null("SummonedAllyBehavior")
			if summon_behavior:
				summon_behavior.bind_card(bound_card_data)
		else:
			# Enemy summons shouldn't try to bind player cards
			push_warning("SummonEffect: bound_card_data provided for non-SummonedAlly; ignoring.")
	
	# --- Sound ---
	SFXPlayer.play(sound if sound else DEFAULT_SUMMON_SOUND)

func apply_to_card_context(ctx: CardActionContext) -> void:
	if !ctx or !summoned_fighter:
		return

	# Track summoned units (still useful even if enemy summoned, for triggers/tooltips)
	ctx.summoned_fighters.append(summoned_fighter)
	ctx.affected_fighters.append(summoned_fighter)
