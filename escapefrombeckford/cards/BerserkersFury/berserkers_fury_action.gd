extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1
@export var melee_impact_sound: Sound = preload("res://audio/aoe_explosion.tres")

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

	var base_damage := maxi(int(attacker_state.combatant_data.apr) + int(bonus_damage), 0)
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

	var any := ctx.runtime.run_attack(attack_ctx)
	for tid in attack_ctx.affected_target_ids:
		var target_id := int(tid)
		if target_id > 0 and !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	if !any:
		return false

	if melee_impact_sound != null:
		ctx.api.play_sfx(melee_impact_sound)

	var death_ctx := DeathContext.new()
	death_ctx.dead_id = attacker_id
	death_ctx.killer_id = attacker_id
	death_ctx.reason = "berserkers_fury"
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		death_ctx.origin_card_uid = String(ctx.card_data.uid)
	ctx.api.resolve_death(death_ctx)
	if !ctx.affected_ids.has(attacker_id):
		ctx.affected_ids.append(attacker_id)

	return true

func _on_card_attack_sequence_done() -> void:
	pass

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [bonus_damage]
