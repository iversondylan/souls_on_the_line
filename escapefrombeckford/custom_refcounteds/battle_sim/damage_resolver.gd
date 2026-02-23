# damage_resolver.gd
class_name DamageResolver extends RefCounted

static func resolve(api: BattleAPI, ctx: DamageContext) -> void:
	if !api or !ctx:
		return

	# HEADLESS SUPPORT:
	# Live expects ctx.target; sim expects ctx.target_id.
	# Require at least one.
	if ctx.target == null and int(ctx.target_id) == 0:
		return

	# If we have a live target but missing id, try to backfill.
	# (Safe even if target is some wrapper; guarded.)
	if int(ctx.target_id) == 0 and ctx.target != null and ctx.target.has_method("get"):
		# You can tailor this if your Fighter exposes combat_id differently.
		if ctx.target.has_property(&"combat_id"):
			ctx.target_id = int(ctx.target.get(&"combat_id"))

	# In SIM, validity is checked via API/state.
	if api.has_method("is_alive") and int(ctx.target_id) != 0:
		if !bool(api.call("is_alive", int(ctx.target_id))):
			return

	# Base amount: SIM wants ctx.base_amount; Live sometimes uses ctx.amount.
	var base := int(ctx.base_amount)
	if base == 0 and int(ctx.amount) != 0:
		base = int(ctx.amount)
	ctx.base_amount = base
	ctx.phase = DamageContext.Phase.PRE_MODIFIERS

	# Apply deal-side and take-side mods through the API
	ctx.amount = int(api.modify_damage_amount(ctx, int(ctx.base_amount)))
	ctx.amount = maxi(ctx.amount, 0)
	ctx.phase = DamageContext.Phase.POST_MODIFIERS

	# Apply to stats (numeric only)
	api.apply_damage_amount(ctx, ctx.amount)
	ctx.armor_damage = int(ctx.armor_damage)
	ctx.health_damage = int(ctx.health_damage)
	ctx.was_lethal = bool(ctx.was_lethal)

	ctx.phase = DamageContext.Phase.APPLIED

	# Reactions (signals / status hooks) live here too (but via API)
	api.on_damage_applied(ctx)
	
