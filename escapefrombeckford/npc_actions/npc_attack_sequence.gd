# npc_attack_sequence.gd

class_name NPCAttackSequence extends NPCEffectSequence

const TARGET_STANDARD := "target_standard"
const TARGET_OPPONENTS := "target_opponents"
const TARGET_ALL := "target_all"

const ATTACK_MODE_MELEE := "melee"
const ATTACK_MODE_RANGED := "ranged"

const DEFAULT_PROJECTILE_SCENE := "res://VFX/projectiles/fireball/fireball.tscn"

@export var melee_impact_sound: Sound = preload("res://audio/melee_impact.tres")
@export var ranged_impact_sound: Sound = preload("res://audio/fireball_impact.tres")

# Old signature kept for compatibility
func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	_run(ctx, on_done)

func _run(ctx: NPCAIContext, on_done: Callable) -> void:
	await run_async(ctx)
	on_done.call()

# New awaitable entry point
func run_async(ctx: NPCAIContext) -> void:
	if !ctx or !ctx.battle_scene:
		return

	var strikes := int(ctx.params.get(NPCKeys.STRIKES, 1))
	var dmg := int(ctx.params.get(NPCKeys.DAMAGE, 0))
	if strikes <= 0:
		return

	# Ensure we always restore visibility if we hid it
	var fighter := ctx.combatant
	if fighter and is_instance_valid(fighter):
		fighter.info_visible(false)

	for i in range(strikes):
		if !_is_attacker_valid(ctx):
			return

		var targets: Array[Fighter] = []
		if ctx.api:
			targets = ctx.api.get_targets_for_attack_sequence(ctx)
		if targets.is_empty():
			continue

		var mode := String(ctx.params.get(NPCKeys.ATTACK_MODE, ATTACK_MODE_MELEE))
		if mode == ATTACK_MODE_MELEE:
			await _melee_strike(ctx, targets, dmg)
		else:
			await _ranged_strike(ctx, targets, dmg)

	await _finish(ctx)

func _is_attacker_valid(ctx: NPCAIContext) -> bool:
	var f := ctx.combatant
	if !f or !is_instance_valid(f):
		return false
	if !f.is_alive():
		return false
	return true

func _melee_strike(ctx: NPCAIContext, targets: Array[Fighter], dmg: int) -> void:
	var f := ctx.combatant
	var bs := ctx.battle_scene
	if !f or !is_instance_valid(f) or !bs:
		return

	var end_pos := _get_mean_position(targets, f)

	var tween := bs.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(f, "global_position", end_pos, 0.4)
	tween.tween_callback(func():
		if _is_attacker_valid(ctx):
			_apply_damage(ctx, targets, dmg, melee_impact_sound)
	)
	tween.tween_interval(0.2)

	await tween.finished

func _ranged_strike(ctx: NPCAIContext, targets: Array[Fighter], dmg: int) -> void:
	var f := ctx.combatant
	var bs := ctx.battle_scene
	if !f or !is_instance_valid(f) or !bs:
		return

	var projectile_path := String(ctx.params.get(NPCKeys.PROJECTILE_SCENE, DEFAULT_PROJECTILE_SCENE))
	var projectile_scene := load(projectile_path)
	if !projectile_scene:
		if _is_attacker_valid(ctx):
			_apply_damage(ctx, targets, dmg, ranged_impact_sound)
		return

	var height := 0.0
	if f.combatant_data:
		height = float(f.combatant_data.height)
	var offset := Vector2(0, -(height * 0.67))

	var start_pos := f.global_position + offset
	var end_pos := _get_mean_position(targets, f) + offset

	var projectile: Node2D = projectile_scene.instantiate()
	bs.add_child(projectile)
	projectile.global_position = start_pos

	var group := f.get_parent()
	if group and !group.faces_right:
		projectile.scale.x *= -1
	
	var tween := bs.get_tree().create_tween()
	tween.set_trans(Tween.TRANS_QUINT)
	tween.tween_property(projectile, "global_position", end_pos, 0.35)
	tween.tween_callback(func():
		if _is_attacker_valid(ctx):
			_apply_damage(ctx, targets, dmg, ranged_impact_sound)
	)
	tween.tween_callback(func():
		if is_instance_valid(projectile) and projectile.has_method("play_impact"):
			projectile.play_impact()
	)
	tween.tween_interval(0.2)

	await tween.finished

	if is_instance_valid(projectile):
		projectile.queue_free()

func _finish(ctx: NPCAIContext) -> void:
	var f := ctx.combatant
	var bs := ctx.battle_scene
	if !bs:
		return

	# If attacker vanished, nothing to animate
	if !f or !is_instance_valid(f):
		return

	var explode := bool(ctx.params.get(NPCKeys.EXPLODE_ON_FINISH, false))
	var tween := bs.get_tree().create_tween().set_trans(Tween.TRANS_QUINT)

	if explode:
		tween.tween_callback(func():
			if is_instance_valid(f):
				if bs.api:
					bs.api.resolve_death(f.combat_id, "explode_on_finish")
				else:
					f.die()
		)
	else:
		tween.tween_property(f, "position", f.anchor_position, 0.4)

	await tween.finished

	if is_instance_valid(f):
		f.info_visible(true)

func _apply_damage(ctx: NPCAIContext, targets: Array[Fighter], base_dmg: int, impact_sound: Resource) -> void:
	var dmg_effect := DamageEffect.new()
	dmg_effect.targets = targets
	dmg_effect.n_damage = base_dmg
	dmg_effect.source = ctx.combatant # NEW: attacker becomes the source
	# I added params to DamageEffect so that LiveBattleAPI._run_damage_op() could know if it's a ranged attack and choose the right sound to play.
	dmg_effect.params = ctx.params.duplicate() # <- NEW: params from the context are transferred to the effect and then transferred to the DamageContext
	dmg_effect.sound = impact_sound
	dmg_effect.execute(ctx.battle_scene.api)

func _get_mean_position(targets: Array[Fighter], fallback: Fighter) -> Vector2:
	if targets.is_empty():
		return fallback.anchor_position

	var sum := Vector2.ZERO
	for t in targets:
		if t:
			sum += t.global_position
	return sum / float(targets.size())
