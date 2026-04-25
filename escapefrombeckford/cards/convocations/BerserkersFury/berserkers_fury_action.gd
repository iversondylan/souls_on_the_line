extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false
	if ctx.target_ids.is_empty():
		return false

	var attacker_id := int(ctx.target_ids[0])
	if attacker_id <= 0 or !ctx.api.is_alive(attacker_id):
		return false

	var attacker_state := ctx.api.state.get_unit(attacker_id) if ctx.api.state != null else null
	if attacker_state == null or attacker_state.combatant_data == null:
		return false

	var base_damage := maxi(int(attacker_state.combatant_data.ap) + int(bonus_damage), 0)
	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.runtime = ctx.runtime
	attack_ctx.attacker_id = attacker_id
	attack_ctx.source_id = attacker_id
	attack_ctx.strikes = maxi(int(attacks), 1)
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.ENEMIES)
	attack_ctx.base_damage = base_damage
	attack_ctx.deal_modifier_type = int(Modifier.Type.DMG_DEALT)
	attack_ctx.take_modifier_type = int(Modifier.Type.DMG_TAKEN)
	attack_ctx.reason = "berserkers_fury"
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = ctx.api
	attack_ctx.targeting_ctx.source_id = attacker_id
	attack_ctx.targeting_ctx.target_type = int(attack_ctx.targeting)
	attack_ctx.targeting_ctx.attack_mode = int(attack_ctx.attack_mode)

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

	var any := ctx.runtime.run_attack(attack_ctx)
	writer.scope_end(attack_now_scope)

	for tid in attack_ctx.affected_target_ids:
		var target_id := int(tid)
		if target_id > 0 and !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	if !any:
		return false

	return true

func get_description_value(_ctx: CardActionContext) -> String:
	return str(int(bonus_damage))
