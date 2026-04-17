# pending_intent_modifier_resolver.gd

class_name PendingIntentModifierResolver extends RefCounted

static func get_modified_value(
	ctx: NPCAIContext,
	base: int,
	mod_type: Modifier.Type,
	source_id: int
) -> int:
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return base

	var api: SimBattleAPI = ctx.api
	if api.state == null:
		return base

	# Pending stacks are now fully live, so intent math uses the same query path as runtime.
	return SimModifierResolver.get_modified_value(api, base, mod_type, source_id)

static func get_attack_display_components(
	ctx: NPCAIContext,
	base_damage: int,
	base_banish_damage: int,
	source_id: int
) -> Dictionary:
	var normal_amount := get_modified_value(ctx, int(base_damage), Modifier.Type.DMG_DEALT, source_id)
	var banish_amount := get_modified_value(ctx, int(base_banish_damage), Modifier.Type.BANISH_DMG_DEALT, source_id)
	return {
		"damage": maxi(int(normal_amount), 0),
		"banish_damage": maxi(int(banish_amount), 0),
		"total": maxi(int(normal_amount), 0) + maxi(int(banish_amount), 0),
	}

static func get_preview_attack_strikes(
	ctx: NPCAIContext,
	base_strikes: int,
	source_id: int
) -> int:
	if ctx == null or ctx.api == null or !(ctx.api is SimBattleAPI):
		return maxi(int(base_strikes), 1)

	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.attacker_id = int(source_id)
	attack_ctx.source_id = int(source_id)
	attack_ctx.strikes = maxi(int(base_strikes), 1)
	SimStatusSystem.on_attack_will_run(ctx.api, attack_ctx)
	return maxi(int(attack_ctx.strikes), 1)
