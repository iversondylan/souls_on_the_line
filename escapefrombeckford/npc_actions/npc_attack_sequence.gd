# npc_attack_sequence.gd

class_name NPCAttackSequence extends NPCEffectSequence

const TARGET_STANDARD := "target_standard"
const TARGET_OPPONENTS := "target_opponents"
const TARGET_ALL := "target_all"

#const ATTACK_MODE_MELEE := "melee"
#const ATTACK_MODE_RANGED := "ranged"

const DEFAULT_PROJECTILE_SCENE := "res://VFX/projectiles/fireball/fireball.tscn"
#
#@export var melee_impact_sound: Sound = preload("res://audio/melee_impact.tres")
#@export var ranged_impact_sound: Sound = preload("res://audio/fireball_impact.tres")
#
## Old signature kept for compatibility
#func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	#_run(ctx, on_done)
#
#func _run(ctx: NPCAIContext, on_done: Callable) -> void:
	#await run_async(ctx)
	#on_done.call()
#
## New awaitable entry point
#func run_async(ctx: NPCAIContext) -> void:
	#if !ctx or !ctx.battle_scene:
		#return
#
	#var strikes := int(ctx.params.get(Keys.STRIKES, 1))
	#var dmg := int(ctx.params.get(Keys.DAMAGE, 0))
	#if strikes <= 0:
		#return
#
	## Ensure we always restore visibility if we hid it
	#var fighter := ctx.combatant
	#if fighter and is_instance_valid(fighter):
		#fighter.info_visible(false)
#
	#for i in range(strikes):
		#if !_is_attacker_valid(ctx):
			#return
#
		#var targets: Array[Fighter] = []
		#if ctx.api:
			#targets = ctx.api.get_targets_for_attack_sequence(ctx)
		#if targets.is_empty():
			#continue
#
		#var mode := int(ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
		#if mode == Attack.Mode.MELEE:
			#await _melee_strike(ctx, targets, dmg)
		#else:
			#await _ranged_strike(ctx, targets, dmg)
#
	#await _finish(ctx)
#
#func _is_attacker_valid(ctx: NPCAIContext) -> bool:
	#var f := ctx.combatant
	#if !f or !is_instance_valid(f):
		#return false
	#if !f.is_alive():
		#return false
	#return true
#
#func _melee_strike(ctx: NPCAIContext, targets: Array[Fighter], dmg: int) -> void:
	#var f := ctx.combatant
	#var bs := ctx.battle_scene
	#if !f or !is_instance_valid(f) or !bs:
		#return
#
	#var end_pos := _get_mean_position(targets, f)
#
	#var tween := bs.get_tree().create_tween()
	#tween.set_trans(Tween.TRANS_QUINT)
	#tween.tween_property(f, "global_position", end_pos, 0.4)
	#tween.tween_callback(func():
		#if _is_attacker_valid(ctx):
			#_apply_damage(ctx, targets, dmg, melee_impact_sound)
	#)
	#tween.tween_interval(0.2)
#
	#await tween.finished
#
#func _ranged_strike(ctx: NPCAIContext, targets: Array[Fighter], dmg: int) -> void:
	#var f := ctx.combatant
	#var bs := ctx.battle_scene
	#if !f or !is_instance_valid(f) or !bs:
		#return
#
	#var projectile_path := String(ctx.params.get(Keys.PROJECTILE_SCENE, DEFAULT_PROJECTILE_SCENE))
	#var projectile_scene := load(projectile_path)
	#if !projectile_scene:
		#if _is_attacker_valid(ctx):
			#_apply_damage(ctx, targets, dmg, ranged_impact_sound)
		#return
#
	#var height := 0.0
	#if f.combatant_data:
		#height = float(f.combatant_data.height)
	#var offset := Vector2(0, -(height * 0.67))
#
	#var start_pos := f.global_position + offset
	#var end_pos := _get_mean_position(targets, f) + offset
#
	#var projectile: Node2D = projectile_scene.instantiate()
	#bs.add_child(projectile)
	#projectile.global_position = start_pos
#
	#var group := f.get_parent()
	#if group and !group.faces_right:
		#projectile.scale.x *= -1
	#
	#var tween := bs.get_tree().create_tween()
	#tween.set_trans(Tween.TRANS_QUINT)
	#tween.tween_property(projectile, "global_position", end_pos, 0.35)
	#tween.tween_callback(func():
		#if _is_attacker_valid(ctx):
			#_apply_damage(ctx, targets, dmg, ranged_impact_sound)
	#)
	#tween.tween_callback(func():
		#if is_instance_valid(projectile) and projectile.has_method("play_impact"):
			#projectile.play_impact()
	#)
	#tween.tween_interval(0.2)
#
	#await tween.finished
#
	#if is_instance_valid(projectile):
		#projectile.queue_free()
#
#func _finish(ctx: NPCAIContext) -> void:
	#var f := ctx.combatant
	#var bs := ctx.battle_scene
	#if !bs:
		#return
#
	## If attacker vanished, nothing to animate
	#if !f or !is_instance_valid(f):
		#return
#
	#var explode := bool(ctx.params.get(Keys.EXPLODE_ON_FINISH, false))
	#var tween := bs.get_tree().create_tween().set_trans(Tween.TRANS_QUINT)
#
	#if explode:
		#tween.tween_callback(func():
			#if is_instance_valid(f):
				#if bs.api:
					#bs.api.resolve_death(f.combat_id, "explode_on_finish")
				#else:
					#f.die()
		#)
	#else:
		#tween.tween_property(f, "position", f.anchor_position, 0.4)
#
	#await tween.finished
#
	#if is_instance_valid(f):
		#f.info_visible(true)
#
#func _apply_damage(ctx: NPCAIContext, targets: Array[Fighter], base_dmg: int, impact_sound: Resource) -> void:
	##print("npc_attack_sequence.gd _apply_damage() source: ", ctx.combatant.name, ", base_dmg: ", base_dmg)
	#var dmg_effect := DamageEffect.new()
	#dmg_effect.targets = targets
	#dmg_effect.n_damage = base_dmg
	#dmg_effect.source = ctx.combatant # NEW: attacker becomes the source
	## I added params to DamageEffect so that LiveBattleAPI._run_damage_op() could know if it's a ranged attack and choose the right sound to play.
	#dmg_effect.params = ctx.params.duplicate() # <- NEW: params from the context are transferred to the effect and then transferred to the DamageContext
	#dmg_effect.sound = impact_sound
	#dmg_effect.execute(ctx.battle_scene.api)
#
#func _get_mean_position(targets: Array[Fighter], fallback: Fighter) -> Vector2:
	#if targets.is_empty():
		#return fallback.anchor_position
#
	#var sum := Vector2.ZERO
	#for t in targets:
		#if t:
			#sum += t.global_position
	#return sum / float(targets.size())
#
func execute_sim(ctx: NPCAIContext) -> void:
	if ctx == null:
		return

	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("NPCAttackSequence.execute_sim: missing runtime")
		return

	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.runtime = runtime
	attack_ctx.attacker_id = int(ctx.cid)
	attack_ctx.source_id = int(ctx.cid)
	attack_ctx.params = ctx.params if ctx.params != null else {}
	attack_ctx.strikes = maxi(int(attack_ctx.params.get(Keys.STRIKES, 1)), 1)
	attack_ctx.attack_mode = int(attack_ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	attack_ctx.targeting = int(attack_ctx.params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	attack_ctx.projectile_scene = String(attack_ctx.params.get(Keys.PROJECTILE_SCENE, ""))
	attack_ctx.base_damage = int(attack_ctx.params.get(Keys.DAMAGE, 0))
	attack_ctx.base_damage_melee = int(attack_ctx.params.get(Keys.DAMAGE_MELEE, attack_ctx.base_damage))
	attack_ctx.base_damage_ranged = int(attack_ctx.params.get(Keys.DAMAGE_RANGED, attack_ctx.base_damage))
	attack_ctx.deal_modifier_type = int(attack_ctx.params.get(Keys.DEAL_MOD_TYPE, Modifier.Type.DMG_DEALT))
	attack_ctx.take_modifier_type = int(attack_ctx.params.get(Keys.TAKE_MOD_TYPE, Modifier.Type.DMG_TAKEN))
	attack_ctx.reason = "npc_attack"
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = ctx.api
	attack_ctx.targeting_ctx.source_id = int(ctx.cid)
	attack_ctx.targeting_ctx.target_type = int(attack_ctx.targeting)
	attack_ctx.targeting_ctx.attack_mode = int(attack_ctx.attack_mode)
	attack_ctx.targeting_ctx.params = attack_ctx.params

	runtime.run_attack(attack_ctx)
