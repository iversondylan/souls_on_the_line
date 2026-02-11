# live_battle_api.gd
class_name LiveBattleAPI extends BattleAPI


const SUMMONED_ALLY_SCN := "res://scenes/turn_takers/summoned_ally.tscn"
const ENEMY_SCN := "res://scenes/turn_takers/enemy.tscn"

const DEFAULT_SUMMON_DATA := "res://fighters/BasicClone/basic_clone_data.tres"
const DEFAULT_SUMMON_SOUND := "res://audio/summon_zap.tres"

var battle_scene: BattleScene
var runner: BattleResolutionRunner

func _init(_battle_scene: BattleScene) -> void:
	battle_scene = _battle_scene
	runner = battle_scene.runner
	if runner:
		runner.api = self

func observe_stats_changed(fighter: Fighter) -> void:
	# Optional: runner can log this later
	# For now, do nothing.
	pass

# --------------------------
# Public API verbs
# --------------------------

func resolve_damage(ctx: DamageContext) -> void:
	if !ctx:
		return
	if runner:
		runner.enqueue_damage(ctx)

func resolve_death(combat_id: int, reason := "") -> void:
	if combat_id <= 0:
		return
	if runner:
		runner.enqueue_death(combat_id, reason)

func apply_status(ctx: StatusContext) -> void:
	if !ctx:
		return
	if runner:
		runner.enqueue_apply_status(ctx)

func remove_status(ctx: RemoveStatusContext) -> void:
	if !ctx:
		return
	if runner:
		runner.enqueue_remove_status(ctx)

func summon(ctx: SummonContext) -> void:
	if runner and ctx:
		runner.enqueue_summon(ctx)

# --------------------------
# Damage pipeline (LIVE)
# --------------------------

func _modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := base

	# Deal-side
	if ctx.source and ctx.source.modifier_system:
		amount = ctx.source.modifier_system.get_modified_value(amount, ctx.deal_modifier_type)

	# Take-side
	if ctx.target and ctx.target.modifier_system:
		amount = ctx.target.modifier_system.get_modified_value(amount, ctx.take_modifier_type)

	return amount

func _apply_damage_amount(ctx: DamageContext, amount: int) -> void:
	# Numeric only, fill ctx results
	if !ctx.target or !ctx.target.combatant_data:
		return

	var pre_armor := ctx.target.combatant_data.armor
	var health_loss := ctx.target.combatant_data.take_damage(amount)

	ctx.health_damage = health_loss
	ctx.armor_damage = maxi(mini(amount, pre_armor), 0)
	ctx.was_lethal = !ctx.target.combatant_data.is_alive()

func _on_damage_applied(ctx: DamageContext) -> void:
	# Reactions first (gameplay)
	if ctx.target:
		ctx.target.damage_taken.emit(ctx)
		if ctx.target.combatant and ctx.target.combatant.status_grid:
			ctx.target.combatant.status_grid.on_damage_taken(ctx)

	# Presentation (live-only)
	if ctx.target:
		Shaker.shake(ctx.target, 16, 0.15)
		ctx.target._spawn_damage_number_or_block(ctx) # if private, wrap it

# This is what the runner awaits.
func _run_damage_op(ctx: DamageContext) -> void:
	# coroutine body
	if !ctx:
		return

	# Hydrate target/source if ids exist but nodes are missing
	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)
	if !ctx.source and ctx.source_id != 0:
		ctx.source = battle_scene.get_combatant_by_id(ctx.source_id, true)

	if !ctx.target:
		return

	# If dead already, do not apply numeric damage.
	if !ctx.target.is_alive():
		return

	ctx.phase = DamageContext.Phase.PRE_MODIFIERS
	ctx.amount = ctx.base_amount

	var amount := _modify_damage_amount(ctx, ctx.amount)
	amount = maxi(amount, 0)

	ctx.amount = amount
	ctx.phase = DamageContext.Phase.POST_MODIFIERS

	_apply_damage_amount(ctx, ctx.amount)

	ctx.phase = DamageContext.Phase.APPLIED
	_on_damage_applied(ctx)

	if ctx.was_lethal and ctx.target_id != 0:
		# Queue death immediately AFTER showing the hit.
		# If you want a tiny “impact beat”, do it here.
		await battle_scene.get_tree().create_timer(0.05).timeout
		runner.enqueue_death(ctx.target_id, "damage")

# --------------------------
# Death pipeline (LIVE)
# --------------------------

func _run_death_op(combat_id: int, reason: String = "") -> void:
	if combat_id <= 0:
		return

	var f: Fighter = battle_scene.get_combatant_by_id(combat_id, true)
	if !f or !is_instance_valid(f):
		# If it's already gone, make lifecycle consistent.
		if runner:
			runner.mark_removed(combat_id)
		return

	# If it was already removed by something else, bail safely.
	if runner and runner.is_removed(combat_id):
		return

	# ---------------------------------------------------------
	# Data-side: mark dead early so logic stops targeting it,
	# but node stays around to animate & be removed cleanly.
	# ---------------------------------------------------------
	if f.combatant_data:
		f.combatant_data.alive = false

	# ---------------------------------------------------------
	# Gameplay cleanup (used to live in Fighter.die)
	# ---------------------------------------------------------
	if f.combatant and f.combatant.status_grid:
		f.combatant.status_grid.end_non_self_statuses()

	for child in f.get_children():
		if child is FighterBehavior:
			child._on_die()

	# Optional: clear intent visuals right away
	if f.intent_container:
		f.intent_container.clear_display()

	# ---------------------------------------------------------
	# Presentation: fade (awaitable)
	# ---------------------------------------------------------
	var sprite := f.character_sprite
	if sprite:
		var t := f.create_tween()
		t.tween_property(sprite, "modulate", Color.BLACK, 0.3)
		await t.finished
	else:
		await battle_scene.get_tree().process_frame

	# ---------------------------------------------------------
	# Removal: BattleGroup is still the authoritative remover
	# (acting queue reconciliation lives there)
	# ---------------------------------------------------------
	if f.battle_group and is_instance_valid(f.battle_group):
		# Split hooks: side-effects first, then structural removal
		if f.battle_group.has_method("on_combatant_death_side_effects"):
			f.battle_group.on_combatant_death_side_effects(f)
		f.battle_group.remove_combatant(f)
	else:
		# Fallback (should be rare)
		f.queue_free()

	if runner:
		runner.mark_removed(combat_id)

func _run_apply_status_op(ctx: StatusContext) -> void:
	if !ctx:
		return

	# hydrate node references if only ids exist
	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)
	if !ctx.source and ctx.source_id != 0:
		ctx.source = battle_scene.get_combatant_by_id(ctx.source_id, true)

	var f := ctx.target
	if !f or !is_instance_valid(f):
		return
	if runner and runner.is_removed(f.combat_id):
		return

	# If you don't want statuses on dead units, enforce here:
	if !f.is_alive():
		return

	if !f.combatant or !f.combatant.status_grid:
		return

	if !ctx.status:
		return

	# Duplicate here (live insertion rule)
	var status_inst: Status = ctx.status.duplicate()
	f.combatant.status_grid.add_status(status_inst)

	ctx.applied = true

	# Optional: one-frame yield for ordering
	await battle_scene.get_tree().process_frame



func _run_remove_status_op(ctx: RemoveStatusContext) -> void:
	if !ctx:
		return

	# hydrate nodes from ids if needed
	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)
	if !ctx.source and ctx.source_id != 0:
		ctx.source = battle_scene.get_combatant_by_id(ctx.source_id, true)

	var f := ctx.target
	if !f or !is_instance_valid(f):
		return
	if runner and runner.is_removed(f.combat_id):
		return

	if !f.combatant or !f.combatant.status_grid:
		return
	if ctx.status_id == &"":
		return

	# You decide whether removing from dead units is allowed:
	# if !f.is_alive(): return

	# Call ONE canonical StatusGrid API (see note below)
	# Example:
	var removed_count := 0
	if f.combatant.status_grid.has_method("remove_status"):
		removed_count = f.combatant.status_grid.remove_status(ctx.status_id, ctx.remove_all_stacks)
	elif f.combatant.status_grid.has_method("remove_status_by_id"):
		# fallback for your older name
		removed_count = f.combatant.status_grid.remove_status_by_id(String(ctx.status_id))
	else:
		push_warning("StatusGrid has no remove method")
		return

	ctx.removed_count = int(removed_count)
	ctx.removed = ctx.removed_count > 0

	# optional ordering yield
	await battle_scene.get_tree().process_frame

func _run_summon_op(ctx: SummonContext) -> void:
	if !ctx:
		return

	# Use API’s battle_scene (single source of truth)
	if !battle_scene:
		push_warning("LiveBattleAPI._run_summon_op: no battle_scene")
		return

	# clamp inputs
	ctx.group_index = clampi(ctx.group_index, 0, 1)
	var n_in_group := battle_scene.get_n_combatants_in_group(ctx.group_index)
	ctx.insert_index = clampi(ctx.insert_index, 0, n_in_group)

	# choose prefab
	var fighter: Fighter = null
	if ctx.group_index == 1:
		fighter = load(ENEMY_SCN).instantiate()
	else:
		fighter = load(SUMMONED_ALLY_SCN).instantiate()

	if fighter == null:
		push_warning("LiveBattleAPI._run_summon_op: failed instantiate")
		return

	# Add to battle (alloc_combat_id happens inside add_combatant)
	battle_scene.add_combatant(fighter, ctx.group_index, ctx.insert_index)

	# record outputs
	ctx.summoned_fighter = fighter
	ctx.summoned_id = fighter.combat_id

	# ---- CombatantData ----
	var data: CombatantData = (ctx.summon_data if ctx.summon_data else load(DEFAULT_SUMMON_DATA)).duplicate()
	data.init()
	fighter.combatant_data = data

	# ---- AI bootstrap ----
	for child in fighter.get_children():
		if child is NPCAIBehavior:
			child.initiate_first_intents()

	# ---- Optional binding (SummonedAlly only) ----
	if ctx.bound_card_data and fighter is SummonedAlly:
		var summon_behavior := fighter.get_node_or_null("SummonedAllyBehavior")
		if summon_behavior:
			summon_behavior.bind_card(ctx.bound_card_data)

	# ---- SFX ----
	#var s : Sound = ctx.sfx if ctx.sfx else (ctx.summoned_fighter.sound if ctx.summoned_fighter and ctx.summoned_fighter.sound else null)
	# ^ ignore this line if Fighter doesn't own sound
	play_sfx(ctx.sfx if ctx.sfx else load(DEFAULT_SUMMON_SOUND))

	# small yield so “summon then immediately damage” is ordered nicely (optional)
	await battle_scene.get_tree().process_frame
