extends CardAction

class_name DamageTargetsAction

@export var base_damage: int = 5
@export var attack_count: int = 1
@export var sound: Sound = preload("uid://c6myiupet7ros")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.runtime == null:
		return false

	var source_id := int(ctx.source_id)
	if source_id <= 0:
		return false

	var targets := ctx.target_ids
	if targets.is_empty():
		return false
	var explicit_targets: Array[int] = []
	for tid in targets:
		explicit_targets.append(int(tid))

	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.runtime = ctx.runtime
	attack_ctx.attacker_id = source_id
	attack_ctx.source_id = source_id
	attack_ctx.strikes = maxi(int(attack_count), 1)
	attack_ctx.attack_mode = int(Attack.Mode.MELEE)
	attack_ctx.targeting = int(Attack.Targeting.STANDARD)
	attack_ctx.base_damage = int(base_damage)
	attack_ctx.deal_modifier_type = int(Modifier.Type.DMG_DEALT)
	attack_ctx.take_modifier_type = int(Modifier.Type.DMG_TAKEN)
	attack_ctx.reason = "card_attack"
	attack_ctx.tags = [&"card_attack"]
	attack_ctx.targeting_ctx = TargetingContext.new()
	attack_ctx.targeting_ctx.api = ctx.api
	attack_ctx.targeting_ctx.source_id = source_id
	attack_ctx.targeting_ctx.target_type = int(attack_ctx.targeting)
	attack_ctx.targeting_ctx.attack_mode = int(attack_ctx.attack_mode)
	attack_ctx.targeting_ctx.explicit_target_ids = explicit_targets

	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		attack_ctx.origin_card_uid = String(ctx.card_data.uid)

	var any := ctx.runtime.run_attack(attack_ctx)
	for tid in attack_ctx.affected_target_ids:
		var target_id := int(tid)
		if target_id > 0 and !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	return any


func description_arity() -> int:
	return 1


func get_description_values(_ctx: CardActionContext) -> Array:
	return [int(base_damage)]
