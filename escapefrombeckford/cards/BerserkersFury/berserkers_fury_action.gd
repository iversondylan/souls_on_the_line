extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1
@export var melee_impact_sound: Sound = preload("res://audio/aoe_explosion.tres")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if ctx.target_ids.is_empty():
		return false

	var attacker_id := int(ctx.target_ids[0])
	if attacker_id <= 0 or !ctx.api.is_alive(attacker_id):
		return false

	var attacker_state := ctx.api.state.get_unit(attacker_id) if ctx.api.state != null else null
	if attacker_state == null or attacker_state.combatant_data == null:
		return false

	var enemy_ids := ctx.api.get_enemies_of(attacker_id)
	if enemy_ids.is_empty():
		return false

	var base_damage := maxi(int(attacker_state.combatant_data.apr) + int(bonus_damage), 0)
	var strike_count := maxi(int(attacks), 1)
	var any := false

	for tid in enemy_ids:
		var target_id := int(tid)
		if target_id <= 0 or !ctx.api.is_alive(target_id):
			continue

		for _i in range(strike_count):
			var d := DamageContext.new()
			d.source_id = attacker_id
			d.target_id = target_id
			d.base_amount = base_damage
			d.deal_modifier_type = int(Modifier.Type.DMG_DEALT)
			d.take_modifier_type = int(Modifier.Type.DMG_TAKEN)
			ctx.api.resolve_damage_immediate(d)
			any = true

		if !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	if !any:
		return false

	if melee_impact_sound != null:
		ctx.api.play_sfx(melee_impact_sound)

	ctx.api.resolve_death(attacker_id, "berserkers_fury", attacker_id)
	if !ctx.affected_ids.has(attacker_id):
		ctx.affected_ids.append(attacker_id)

	return true

func _on_card_attack_sequence_done() -> void:
	pass

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [bonus_damage]
