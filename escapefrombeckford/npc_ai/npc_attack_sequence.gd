# npc_attack_sequence.gd

class_name NPCAttackSequence extends NPCEffectSequence

func execute(ctx: NPCAIContext) -> void:
	if ctx == null:
		return

	var runtime := ctx.runtime if ctx.runtime != null else (ctx.api.runtime if ctx.api != null else null)
	if runtime == null:
		push_warning("npc_attack_sequence.gd execute(): missing runtime")
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
	attack_ctx.base_banish_amount = int(attack_ctx.params.get(Keys.BANISH_DAMAGE, 0))
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
