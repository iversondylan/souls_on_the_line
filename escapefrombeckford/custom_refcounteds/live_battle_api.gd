# live_battle_api.gd
class_name LiveBattleAPI extends BattleAPI

const SUMMONED_ALLY_SCN := "res://scenes/turn_takers/summoned_ally.tscn"
const ENEMY_SCN := "res://scenes/turn_takers/enemy.tscn"

const DEFAULT_SUMMON_DATA := "res://fighters/BasicClone/basic_clone_data.tres"
const DEFAULT_SUMMON_SOUND := "res://audio/summon_zap.tres"

const DEFAULT_MELEE_SOUND := "res://audio/melee_impact.tres"
const DEFAULT_RANGED_SOUND := "res://audio/fireball_impact.tres"

var battle_scene: BattleScene
var turn_engine: TurnEngineCore
var runner: BattleResolutionRunner

func _init(_battle_scene: BattleScene) -> void:
	battle_scene = _battle_scene
	runner = battle_scene.runner
	if runner:
		runner.api = self
	#turn_engine = TurnEngine.new(self, battle_scene)

func observe_stats_changed(fighter: Fighter) -> void:
	#print("SO MANY STATS CHANGED")
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
	if ctx.sound:
		play_sfx(ctx.sound)
	else:
		var attack_mode: String = ctx.params.get(NPCKeys.ATTACK_MODE, NPCAttackSequence.ATTACK_MODE_MELEE)
		if attack_mode == NPCAttackSequence.ATTACK_MODE_RANGED:
			play_sfx(load(DEFAULT_RANGED_SOUND))
		else:
			play_sfx(load(DEFAULT_MELEE_SOUND))


func resolve_damage_immediate(ctx: DamageContext) -> void:
	# hydrate (optional), then
	DamageResolver.resolve(self, ctx)
	if ctx.sound:
		play_sfx(ctx.sound)
	else:
		var attack_mode: String = ctx.params.get(NPCKeys.ATTACK_MODE, NPCAttackSequence.ATTACK_MODE_MELEE)
		if attack_mode == NPCAttackSequence.ATTACK_MODE_RANGED:
			play_sfx(load(DEFAULT_RANGED_SOUND))
		else:
			play_sfx(load(DEFAULT_MELEE_SOUND))
	if ctx.was_lethal:
		runner.enqueue_death(ctx.target_id, "damage")

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

func run_status_proc(target_id: int, proc_type: Status.ProcType) -> void:
	#print("live_battle_api.gd run_status_proc()")
	if runner:
		runner.enqueue_status_proc(target_id, proc_type)

func summon(ctx: SummonContext) -> void:
	if runner and ctx:
		runner.enqueue_summon(ctx)

func resolve_heal(ctx: HealContext) -> void:
	if !ctx:
		return
	if runner:
		runner.enqueue_heal(ctx)

func resolve_move(ctx: MoveContext) -> void:
	print("live_battle_api.gd resolve_move()")
	if !ctx:
		return
	if runner:
		runner.enqueue_move(ctx)

func resolve_attack_now(ctx: AttackNowContext) -> void:
	if !ctx:
		return
	if runner:
		runner.enqueue_attack_now(ctx)

# --------------------------
# Damage pipeline (LIVE)
# --------------------------

func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	
	var amount := base
	#print("live_battle_api.gd modify_damage_amount() base amount: ", amount)
	# Deal-side
	if ctx.source and ctx.source.modifier_system:
		amount = ctx.source.modifier_system.get_modified_value(amount, ctx.deal_modifier_type)
	#print("live_battle_api.gd modify_damage_amount() deal amount: ", amount)
	# Take-side
	if ctx.target and ctx.target.modifier_system:
		amount = ctx.target.modifier_system.get_modified_value(amount, ctx.take_modifier_type)
	#print("live_battle_api.gd modify_damage_amount() take amount: ", amount)
	return amount

func apply_damage_amount(ctx: DamageContext, amount: int) -> void:
	# Numeric only, fill ctx results
	if !ctx.target or !ctx.target.combatant_data:
		return

	var pre_armor := ctx.target.combatant_data.armor
	var health_loss := ctx.target.combatant_data.take_damage(amount)

	ctx.health_damage = health_loss
	ctx.armor_damage = maxi(mini(amount, pre_armor), 0)
	ctx.was_lethal = !ctx.target.combatant_data.is_alive()

func on_damage_applied(ctx: DamageContext) -> void:
	# Reactions first (gameplay)
	if ctx.target:
		ctx.target.damage_taken.emit(ctx)
		if ctx.target.combatant and ctx.target.combatant.status_grid:
			ctx.target.status_system.on_damage_taken(ctx)

	# Presentation (live-only)
	if ctx.target:
		Shaker.shake(ctx.target, 16, 0.15)
		ctx.target._spawn_damage_number_or_block(ctx) # if private, wrap it



# This is what the runner awaits.
func _run_damage_op(ctx: DamageContext) -> void:
	#print("live_battle_api.gd _run_damage_op()")
	if !ctx:
		return

	# hydrate
	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)
	if !ctx.source and ctx.source_id != 0:
		ctx.source = battle_scene.get_combatant_by_id(ctx.source_id, true)

	if !ctx.target:
		return
	if !ctx.target.is_alive():
		return
		

	
	# central resolver
	DamageResolver.resolve(self, ctx)
	
	# lethal followup timing (if you still want the tiny beat)
	if ctx.was_lethal and ctx.target_id != 0:
		await battle_scene.get_tree().create_timer(0.05).timeout
		runner.enqueue_death(ctx.target_id, "damage")

# --------------------------
# Death pipeline (LIVE)
# --------------------------

func _run_death_op(combat_id: int, _reason: String = "") -> void:
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
		f.status_system.end_non_self_statuses()

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
	
	if turn_engine:
		turn_engine.notify_actor_removed(combat_id)
	
	if runner:
		runner.mark_removed(combat_id)

# live_battle_api.gd

func _run_apply_status_op(ctx: StatusContext) -> void:
	if !ctx:
		return

	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)
	if !ctx.source and ctx.source_id != 0:
		ctx.source = battle_scene.get_combatant_by_id(ctx.source_id, true)

	var f := ctx.target
	if !f or !is_instance_valid(f):
		return
	if runner and runner.is_removed(f.combat_id):
		return
	if !f.is_alive():
		return

	if ctx.status_id == &"":
		return

	if !status_catalog:
		push_warning("LiveBattleAPI._run_apply_status_op: status_catalog is null")
		return

	var proto := status_catalog.get_proto(String(ctx.status_id))
	if !proto:
		push_warning("LiveBattleAPI._run_apply_status_op: unknown status id: %s" % String(ctx.status_id))
		return

	if !f.status_system:
		push_warning("LiveBattleAPI._run_apply_status_op: target has no status_system")
		return

	# Prefer: system duplicates internally OR you duplicate here, but be consistent.
	f.status_system.add_or_reapply(proto, ctx.duration, ctx.intensity)

	ctx.applied = true
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
	if f.status_system.has_method("remove_status"):
		removed_count = f.status_system.remove_status(ctx.status_id, ctx.remove_all_stacks)
	elif f.status_system.has_method("remove_status_by_id"):
		# fallback for your older name
		removed_count = f.status_system.remove_status_by_id(String(ctx.status_id))
	else:
		push_warning("StatusGrid has no remove method")
		return

	ctx.removed_count = int(removed_count)
	ctx.removed = ctx.removed_count > 0

	# optional ordering yield
	await battle_scene.get_tree().process_frame

func _run_status_proc_op(target_id: int, proc_type: Status.ProcType) -> void:
	#print("live_battle_api.gd _run_status_proc_op()")
	var f := battle_scene.get_combatant_by_id(target_id, true)
	if !f or !is_instance_valid(f):
		return
	
	# Data source of truth
	var sys := f.status_system
	if !sys:
		#print("live_battle_api.gd _run_status_proc_op(): no status system")
		f.status_proc_finished.emit(proc_type)
		return
	
	# Build queue of statuses that match proc_type
	var queue := sys.get_all().filter(func(s: Status): return s and s.proc_type == proc_type)
	
	if queue.is_empty():
		#print("live_battle_api.gd _run_status_proc_op(): queue is empty. emitting f.status_proc_finished.emit(proc_type)")
		f.status_proc_finished.emit(proc_type)
		return
	
	var tween := f.create_tween()
	for s in queue:
		#print("live_battle_api.gd _run_status_proc_op(): tweening a queued apply_status.bind(f)")
		tween.tween_callback(s.apply_status.bind(f))
		tween.tween_interval(StatusGrid.STATUS_APPLY_INTERVAL) # keep your constant somewhere shared
	#print("live_battle_api.gd _run_status_proc_op(): awaiting tween.finished...")
	await tween.finished
	#print("live_battle_api.gd _run_status_proc_op(): tween.finished done.")
	# Decrement durations / expire *in the system* (not in view)
	#sys.on_proc_applied(proc_type) # you implement this: duration--, remove expired, emit signals
	#print("live_battle_api.gd _run_status_proc_op(): emitting f.status_proc_finished.emit(proc_type)")
	f._emit_status_proc_finished(proc_type)


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
	if turn_engine:
		turn_engine.notify_summon_added(int(ctx.summoned_id), int(ctx.group_index))
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

func _run_heal_op(ctx: HealContext) -> void:
	if !ctx:
		return

	# Hydrate nodes from ids if needed (helps ordering / robustness)
	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)
	if !ctx.source and ctx.source_id != 0:
		ctx.source = battle_scene.get_combatant_by_id(ctx.source_id, true)

	if !ctx.target:
		return

	# For heals, you usually *don’t* heal dead units.
	# If you later want revive mechanics, that becomes a different op.
	if !ctx.target.is_alive():
		return

	ctx.phase = HealContext.Phase.PRE_MODIFIERS

	# --- (Optional) modifiers later ---
	# If you eventually want "healing done" / "healing taken":
	# amount = ctx.target.modifier_system.get_modified_value(amount, Modifier.Type.HEAL_TAKEN), etc.
	# For now: apply as-is.

	ctx.phase = HealContext.Phase.POST_MODIFIERS

	# Numeric only
	var healed := 0
	if ctx.target.combatant_data:
		healed = ctx.target.combatant_data.heal(ctx)
	ctx.healed_amount = healed

	ctx.phase = HealContext.Phase.APPLIED

	# Presentation / reactions (simple version)
	# If you have a signal like healed_taken, emit it here.
	# You can also spawn a green number, glow, etc.
	# await battle_scene.get_tree().process_frame  # optional ordering beat

func _run_move_op(ctx: MoveContext) -> void:
	print("live_battle_api.gd _run_move_op()")
	if !ctx:
		return

	# hydrate actor/target if needed
	if !ctx.actor and ctx.actor_id != 0:
		ctx.actor = battle_scene.get_combatant_by_id(ctx.actor_id, true)
	if !ctx.target and ctx.target_id != 0:
		ctx.target = battle_scene.get_combatant_by_id(ctx.target_id, true)

	if !ctx.actor:
		return
	if runner and runner.is_removed(ctx.actor_id):
		return

	# Don’t move dead units (unless you later want “corpse shove” mechanics)
	if !ctx.actor.is_alive():
		return

	# Delegate to BattleScene/BattleGroup (authoritative structure)
	battle_scene.execute_move_ctx(ctx)
	
	if turn_engine:
		turn_engine.notify_move_executed(ctx)
	if ctx.sound:
		play_sfx(ctx.sound)

	# tiny yield keeps ordering consistent (optional)
	await battle_scene.get_tree().process_frame



# If later I want “strict runner ordering” for AttackNow, I can do it cleanly by:
# moving strike timing into _run_attack_now_op (runner-controlled),
# and applying damage inline at each strike moment (so it doesn’t need to enqueue to itself).
func _run_attack_now_op(ctx: AttackNowContext) -> void:
	if !ctx:
		return

	if !ctx.attacker and ctx.attacker_id != 0:
		ctx.attacker = battle_scene.get_combatant_by_id(ctx.attacker_id, true)

	var attacker := ctx.attacker
	if !attacker or !is_instance_valid(attacker) or !attacker.is_alive():
		return

	if ctx.sound:
		play_sfx(ctx.sound)

	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = self
	ai_ctx.combatant = attacker
	ai_ctx.combatant_data = attacker.combatant_data
	ai_ctx.battle_scene = battle_scene
	ai_ctx.state = {}
	ai_ctx.params = {}
	ai_ctx.forecast = false

	var strikes := maxi(ctx.strikes, 0)
	if strikes <= 0:
		return
	ai_ctx.params[NPCKeys.STRIKES] = strikes
	ai_ctx.params[NPCKeys.TARGET_TYPE] = NPCAttackSequence.TARGET_STANDARD

	var base_damage := 0
	if ctx.use_base_damage_override:
		base_damage = maxi(ctx.base_damage, 0)
	else:
		if attacker.combatant_data:
			base_damage = attacker.combatant_data.max_mana_red + 1
	ai_ctx.params[NPCKeys.DAMAGE] = maxi(base_damage, 0) # raw only
	#if attacker.modifier_system:
		#base_damage = attacker.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
#
	#ai_ctx.params[NPCKeys.DAMAGE] = maxi(base_damage, 0)

	if ctx.param_models:
		for model in ctx.param_models:
			if model:
				model.change_params(ai_ctx)

	var seq := NPCAttackSequence.new()
	await seq.run_async(ai_ctx)


# Helpers

func is_alive(combat_id: int) -> bool:
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	return f != null and is_instance_valid(f) and f.is_alive()

func get_group(combat_id: int) -> int:
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	if !f or !is_instance_valid(f):
		return -1
	return battle_scene.get_index_of_parent_group(f)

func get_team(combat_id: int) -> int:
	# if team==group, this is identical; keep for semantic clarity
	return get_group(combat_id)

func get_opposing_group(group_index: int) -> int:
	return 1 - clampi(group_index, 0, 1)

func get_combatants_in_group(group_index: int, allow_dead := false) -> Array[int]:
	group_index = clampi(group_index, 0, 1)
	var ids: Array[int] = []
	for f: Fighter in battle_scene.groups[group_index].get_combatants(allow_dead):
		if f and is_instance_valid(f) and f.combat_id > 0:
			if allow_dead or f.is_alive():
				ids.append(f.combat_id)
	return ids

func get_n_combatants_in_group(group_index: int, allow_dead := false) -> int:
	return get_combatants_in_group(group_index, allow_dead).size()

func get_front_combatant_id(group_index: int) -> int:
	group_index = clampi(group_index, 0, 1)
	for f: Fighter in battle_scene.groups[group_index].get_combatants(false):
		if f and is_instance_valid(f) and f.is_alive():
			return f.combat_id
	return 0

func get_enemies_of(combat_id: int) -> Array[int]:
	var g := get_group(combat_id)
	if g == -1:
		return []
	return get_combatants_in_group(get_opposing_group(g), false)

func get_allies_of(combat_id: int) -> Array[int]:
	var g := get_group(combat_id)
	if g == -1:
		return []
	var ids := get_combatants_in_group(g, false)
	ids.erase(combat_id)
	return ids

func get_rank_in_group(combat_id: int) -> int:
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	if !f or !is_instance_valid(f):
		return -1
	return f.get_index()

func has_status(combat_id: int, status_id: StringName) -> bool:
	#print("live_battle_api.gd has_status(combat_id: %s, status_id: %s)" % [combat_id, status_id])
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	if !f or !is_instance_valid(f):
		return false
	if !f.combatant or !f.combatant.status_grid or !f.status_system:
		return false
	return f.status_system.has_status(status_id)

func find_marked_ranged_redirect_target(attacker_id: int) -> int:
	var enemies := get_enemies_of(attacker_id) # ids front->back
	for id in enemies:
		if is_alive(id) and has_status(id, &"marked"):
			return id
	return 0


func get_targets_for_attack_sequence(ai_ctx) -> Array:
	var attacker_id := 0
	if ai_ctx.combatant:
		attacker_id = ai_ctx.combatant.combat_id
	elif ai_ctx.combatant_data:
		attacker_id = ai_ctx.combatant_data.combat_id
	if attacker_id <= 0:
		return []

	var ids := AttackTargeting.get_target_ids(self, attacker_id, ai_ctx.params)
	var out: Array[Fighter] = []
	for id in ids:
		var f := battle_scene.get_combatant_by_id(id, true)
		if f and is_instance_valid(f) and f.is_alive():
			out.append(f)
	return out

func get_player_pos_delta(combat_id: int) -> int:
	# live: use battle_scene.get_player_pos_delta(fighter)
	var fighter := battle_scene.get_combatant_by_id(combat_id)
	return battle_scene.get_player_pos_delta(fighter)
