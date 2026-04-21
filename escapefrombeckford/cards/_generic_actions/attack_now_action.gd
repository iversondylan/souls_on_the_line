# attack_now_action.gd
extends CardAction

@export var attacks: int = 1
@export var param_models: Array[ParamModel]
@export var set_damage_to_attacker_max_health: bool = false
@export var bonus_damage_context_key: StringName = &""

func description_arity() -> int:
	return 0

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

	_apply_optional_damage_overrides(ctx, attacker_state, ai_ctx.params)

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

	var writer := ctx.api.writer if ctx.api != null else null
	if writer == null:
		return false

	var scope_label := "card_attack_now"
	if ctx.card_data != null:
		scope_label = "card_attack_now uid=%s" % String(ctx.card_data.uid)

	var attack_now_scope := writer.scope_begin(
		Scope.Kind.CARD_ATTACK_NOW_TURN,
		scope_label,
		attacker_id,
		{}
	)
	if attack_now_scope == null:
		return false

	var any := false
	any = ctx.runtime.run_attack(attack_ctx)
	writer.scope_end(attack_now_scope)

	for tid in attack_ctx.affected_target_ids:
		var target_id := int(tid)
		if target_id > 0 and !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	return any

func _apply_optional_damage_overrides(
	ctx: CardContext,
	attacker_state: CombatantState,
	params: Dictionary
) -> void:
	if params == null:
		return

	var has_bonus_key := StringName(bonus_damage_context_key) != &""
	if !bool(set_damage_to_attacker_max_health) and !has_bonus_key:
		return

	var base_damage := int(params.get(Keys.DAMAGE_MELEE, params.get(Keys.DAMAGE, 0)))
	if bool(set_damage_to_attacker_max_health) and attacker_state != null:
		base_damage = int(attacker_state.max_health)

	if has_bonus_key and ctx != null:
		base_damage += int(ctx.params.get(bonus_damage_context_key, 0))

	base_damage = maxi(base_damage, 0)
	params[Keys.DAMAGE] = base_damage
	params[Keys.DAMAGE_MELEE] = base_damage
	params[Keys.DAMAGE_RANGED] = base_damage
