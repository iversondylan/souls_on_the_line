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

	var pending_sources := SimStatusSystem.collect_pending_realization_sources(ctx, source_id)
	var tokens := api.get_modifier_tokens_for_cid(source_id, mod_type, pending_sources)
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
