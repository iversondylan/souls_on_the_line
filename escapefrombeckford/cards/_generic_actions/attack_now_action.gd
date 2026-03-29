# attack_now_action.gd
extends CardAction

@export var attacks: int = 1
@export var param_models: Array[ParamModel]

#func activate(ctx: CardActionContext) -> bool:
	#if !ctx or !ctx.battle_scene or !ctx.battle_scene.api:
		#return false
	#if !ctx.resolved_target:
		#return false
	#
	#var resolved_fighters := ctx.resolved_target.fighters
	#if resolved_fighters.is_empty():
		#return false
	#
	#var attacker: Fighter = resolved_fighters[0]
	#if !attacker:
		#return false
	#
	#var eff := AttackNowEffect.new()
	#eff.attacker = attacker
	#eff.attacks = attacks
	#eff.param_models = param_models
	## eff.sound = ctx.card_data.sound  # optional top-level zap; impacts are in seq
#
	#eff.execute(ctx.battle_scene.api)
	#return true

func description_arity() -> int:
	return 0

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return []

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null or ctx.target_ids == null:
		return false
	
	# Use the first selected target as the attacker.
	var attacker_id := 0
	if ctx.target_ids.size() > 0:
		attacker_id = int(ctx.target_ids[0])
	if attacker_id <= 0 or !ctx.api.is_alive(attacker_id):
		return false

	var attacker_state := ctx.api.state.get_unit(attacker_id) if ctx.api.state != null else null
	if attacker_state == null:
		return false

	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = ctx.api
	ai_ctx.runtime = ctx.runtime
	ai_ctx.cid = attacker_id
	ai_ctx.combatant_state = attacker_state
	ai_ctx.combatant_data = attacker_state.combatant_data
	ai_ctx.rng = attacker_state.rng
	ai_ctx.state = {}
	ai_ctx.params = {
		Keys.STRIKES: maxi(int(attacks), 1),
		Keys.TARGET_TYPE: Attack.Targeting.STANDARD
	}
	ai_ctx.forecast = false

	if param_models != null:
		for pm: ParamModel in param_models:
			if pm != null:
				pm.change_params_sim(ai_ctx)

	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.runtime = ctx.runtime
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.strikes = maxi(int(attacks), 1)
	attack_ctx.deal_modifier_type = int(Modifier.Type.DMG_DEALT)
	attack_ctx.take_modifier_type = int(Modifier.Type.DMG_TAKEN)
	attack_ctx.params = ai_ctx.params
	attack_ctx.attack_mode = int(ai_ctx.params.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	attack_ctx.targeting = int(ai_ctx.params.get(Keys.TARGET_TYPE, Attack.Targeting.STANDARD))
	attack_ctx.projectile_scene = String(ai_ctx.params.get(Keys.PROJECTILE_SCENE, ""))
	attack_ctx.reason = "attack_now"
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = ctx.api
	attack_ctx.targeting_ctx.source_id = attacker_id
	attack_ctx.targeting_ctx.target_type = int(attack_ctx.targeting)
	attack_ctx.targeting_ctx.attack_mode = int(attack_ctx.attack_mode)
	attack_ctx.targeting_ctx.params = ai_ctx.params

	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		attack_ctx.origin_card_uid = String(ctx.card_data.uid)

	var any := ctx.runtime.run_attack(attack_ctx)
	for tid in attack_ctx.affected_target_ids:
		var target_id := int(tid)
		if target_id > 0 and !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	return any
