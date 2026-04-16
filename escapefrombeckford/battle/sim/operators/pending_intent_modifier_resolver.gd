# pending_intent_modifier_resolver.gd

class_name PendingIntentModifierResolver extends RefCounted

const PendingStatusSourceSet := preload("res://battle/sim/containers/pending_status_source_set.gd")

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

	var pending_owners: PendingStatusSourceSet = SimStatusSystem.collect_pending_realization_sources(ctx, source_id)
	var tokens := api.get_modifier_tokens_for_cid(source_id, mod_type, pending_owners)
	return SimModifierResolver.apply_tokens(base, mod_type, tokens)

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

	var pending_owners: PendingStatusSourceSet = SimStatusSystem.collect_pending_realization_sources(ctx, source_id)
	var attack_ctx := AttackContext.new()
	attack_ctx.api = ctx.api
	attack_ctx.attacker_id = int(source_id)
	attack_ctx.source_id = int(source_id)
	attack_ctx.strikes = maxi(int(base_strikes), 1)
	SimStatusSystem.on_attack_will_run(ctx.api, attack_ctx, pending_owners)
	return maxi(int(attack_ctx.strikes), 1)
