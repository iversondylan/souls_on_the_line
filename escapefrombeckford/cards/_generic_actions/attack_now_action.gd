# attack_now_action.gd
extends CardAction

@export var attacks: int = 1
@export var param_models: Array[ParamModel]

#func activate(ctx: CardActionContext) -> bool:
	#if !ctx or !ctx.battle_scene or !ctx.battle_scene.api:
		#return false
	#if !ctx.resolved_target:
		#return false
	#
	#var resolved_fighters := ctx.resolved_target.fighters
	#if resolved_fighters.is_empty():
		#return false
	#
	#var attacker: Fighter = resolved_fighters[0]
	#if !attacker:
		#return false
	#
	#var eff := AttackNowEffect.new()
	#eff.attacker = attacker
	#eff.attacks = attacks
	#eff.param_models = param_models
	## eff.sound = ctx.card_data.sound  # optional top-level zap; impacts are in seq
#
	#eff.execute(ctx.battle_scene.api)
	#return true

func description_arity() -> int:
	return 0

#func get_description_values(_ctx: CardActionContext) -> Array:
	#return []

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.target_ids == null:
		return false
	
	# Use the first selected target as the attacker.
	var attacker_id := 0
	if ctx.target_ids.size() > 0:
		attacker_id = int(ctx.target_ids[0])
	if attacker_id <= 0:
		return false
	
	var spec := SimAttackSpec.new()
	spec.attacker_id = attacker_id
	spec.strikes = maxi(int(attacks), 1)
	spec.base_damage = 0 # if AttackNow has its own base; else default 0 and let param models set it
	spec.params = {
		Keys.STRIKES: spec.strikes,
		Keys.TARGET_TYPE: Attack.Targeting.STANDARD
	}
	spec.param_models = param_models
	return (ctx.api as SimBattleAPI).apply_attack_now(spec)
