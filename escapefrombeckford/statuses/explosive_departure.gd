class_name ExplosiveDepartureStatus extends Status

const ID := &"explosive_departure"
const Removal = preload("res://core/keys_values/removal_values.gd")


func get_id() -> StringName:
	return ID


func get_tooltip(stacks: int = 0) -> String:
	return "Explosive Departure: On Death, deal %s damage to all enemies." % stacks


func on_removal(ctx: SimStatusContext, removal_ctx) -> void:
	_trigger_removal_burst(ctx, removal_ctx, "explosive_departure")


func _trigger_removal_burst(ctx: SimStatusContext, removal_ctx, attack_reason: String) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.api.runtime == null:
		return
	if removal_ctx == null or int(removal_ctx.removal_type) != int(Removal.Type.DEATH):
		return
	if int(removal_ctx.target_id) != int(ctx.owner_id):
		return

	var stacks := maxi(int(ctx.get_stacks()), 0)
	if stacks <= 0:
		return

	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.runtime = ctx.api.runtime
	attack_ctx.attacker_id = int(ctx.owner_id)
	attack_ctx.source_id = int(ctx.owner_id)
	attack_ctx.allow_dead_source = true
	attack_ctx.strikes = 1
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.ENEMIES)
	attack_ctx.base_damage = stacks
	attack_ctx.base_damage_melee = stacks
	attack_ctx.base_damage_ranged = stacks
	attack_ctx.deal_modifier_type = int(Modifier.Type.DMG_DEALT)
	attack_ctx.take_modifier_type = int(Modifier.Type.DMG_TAKEN)
	attack_ctx.reason = attack_reason
	attack_ctx.tags = [ID]
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = ctx.api
	attack_ctx.targeting_ctx.source_id = int(ctx.owner_id)
	attack_ctx.targeting_ctx.allow_dead_source = true
	attack_ctx.targeting_ctx.target_type = int(attack_ctx.targeting)
	attack_ctx.targeting_ctx.attack_mode = int(attack_ctx.attack_mode)

	ctx.api.runtime.run_attack(attack_ctx)
