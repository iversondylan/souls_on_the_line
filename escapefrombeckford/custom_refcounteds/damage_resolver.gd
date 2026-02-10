# damage_resolver.gd
class_name DamageResolver extends RefCounted

static func resolve(api: BattleAPI, ctx: DamageContext) -> void:
	if !api or !ctx:
		return
	if !ctx.target:
		return

	ctx.phase = DamageContext.Phase.PRE_MODIFIERS

	# Apply deal-side and take-side mods through the API
	# (LiveAPI uses Fighter.modifier_system, SimAPI uses SimBattle.get_modified_value)
	ctx.amount = api.modify_damage_amount(ctx, ctx.base_amount)

	ctx.amount = maxi(ctx.amount, 0)
	ctx.phase = DamageContext.Phase.POST_MODIFIERS

	# Apply to stats (numeric only)
	var result := api.apply_damage_amount(ctx, ctx.amount)
	ctx.armor_damage = int(result.get("armor_damage", 0))
	ctx.health_damage = int(result.get("health_damage", 0))
	ctx.was_lethal = bool(result.get("was_lethal", false))

	ctx.phase = DamageContext.Phase.APPLIED

	# Reactions (signals / status hooks) live here too (but via API)
	api.on_damage_applied(ctx)

	if ctx.was_lethal:
		api.resolve_death(ctx.target.combat_id, "damage")
