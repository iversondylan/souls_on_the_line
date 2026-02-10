# sim_battle_api.gd
class_name SimBattleAPI extends BattleAPI

var battle: SimBattle

func _init(_battle: SimBattle) -> void:
	battle = _battle

func modify_damage_amount(ctx: DamageContext, base: int) -> int:
	var amount := base
	var src_id := ctx.source_id
	var tgt_id := ctx.target_id

	amount = battle.get_modified_value(src_id, amount, ctx.deal_modifier_type)
	amount = battle.get_modified_value(tgt_id, amount, ctx.take_modifier_type)
	return amount

func apply_damage_amount(ctx: DamageContext, amount: int) -> Dictionary:
	# Sim fighter must own numeric data (armor/health). Right now SimFighter doesn’t.
	# So step 1 is: give SimFighter a CombatantData-like stats struct or copied fields.
	var f := battle.get_fighter(ctx.target_id)
	return f.stats.apply_damage_amount(amount)

func on_damage_applied(ctx: DamageContext) -> void:
	# Sim hooks: statuses that react to damage, AI state updates, etc.
	# You can mirror StatusGrid.on_damage_taken semantics here later.
	battle.on_damage_taken(ctx)

func resolve_death(combat_id: int, reason := "") -> void:
	var f := battle.get_fighter(combat_id)
	if f:
		f.alive = false
