# live_battle_api.gd

class_name LiveBattleAPI extends BattleAPI

var battle_scene: BattleScene

func _init(_battle_scene: BattleScene) -> void:
	battle_scene = _battle_scene

func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := base

	# deal-side
	if ctx.source and ctx.source.modifier_system:
		amount = ctx.source.modifier_system.get_modified_value(amount, ctx.deal_modifier_type)

	# take-side
	if ctx.target and ctx.target.modifier_system:
		amount = ctx.target.modifier_system.get_modified_value(amount, ctx.take_modifier_type)

	return amount

func apply_damage_amount(ctx: DamageContext, amount: int) -> Dictionary:
	return ctx.target.combatant_data.apply_damage_amount(amount)

func on_damage_applied(ctx: DamageContext) -> void:
	# These are your current synchronous reactions
	if ctx.target:
		ctx.target.damage_taken.emit(ctx)
		if ctx.target.combatant and ctx.target.combatant.status_grid:
			ctx.target.combatant.status_grid.on_damage_taken(ctx)

	# Presentation stays in Live API (or in a separate presenter object)
	if ctx.target:
		Shaker.shake(ctx.target, 16, 0.15)
		ctx.target._spawn_damage_number_or_block(ctx) # if private, wrap it

func resolve_death(combat_id: int, reason := "") -> void:
	var f := battle_scene.get_combatant_by_id(combat_id) # or however you lookup
	if f and f.is_alive():
		f.die()
