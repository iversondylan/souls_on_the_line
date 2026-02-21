# damage_resolver.gd

class_name DamageResolver extends RefCounted

static func resolve(api: BattleAPI, ctx: DamageContext) -> void:
	pass
	
	# fix me
	
	#if !api or !ctx:
		#return
	#if !ctx.target:
		#return
#
	#ctx.phase = DamageContext.Phase.PRE_MODIFIERS
#
	## Apply deal-side and take-side mods through the API
	## (LiveAPI uses Fighter.modifier_system, SimAPI uses SimBattle.get_modified_value)
	#ctx.amount = api.modify_damage_amount(ctx, ctx.base_amount)
#
	#ctx.amount = maxi(ctx.amount, 0)
	#ctx.phase = DamageContext.Phase.POST_MODIFIERS
#
	## Apply to stats (numeric only)
	#api.apply_damage_amount(ctx, ctx.amount)
	#ctx.armor_damage = int(ctx.armor_damage)
	#ctx.health_damage = int(ctx.health_damage)
	#ctx.was_lethal = bool(ctx.was_lethal)
#
	#ctx.phase = DamageContext.Phase.APPLIED
#
	## Reactions (signals / status hooks) live here too (but via API)
	#api.on_damage_applied(ctx)
#
	##if ctx.was_lethal:
		##api.resolve_death(ctx.target.combat_id, "damage")
