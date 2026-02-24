# attack_now_action.gd
extends CardAction

@export var attacks: int = 1
@export var param_models: Array[ParamModel]

func activate(ctx: CardActionContext) -> bool:
	if !ctx or !ctx.battle_scene or !ctx.battle_scene.api:
		return false
	if !ctx.resolved_target:
		return false

	var resolved_fighters := ctx.resolved_target.fighters
	if resolved_fighters.is_empty():
		return false

	var attacker: Fighter = resolved_fighters[0]
	if !attacker:
		return false

	var eff := AttackNowEffect.new()
	eff.attacker = attacker
	eff.attacks = attacks
	eff.param_models = param_models
	# eff.sound = ctx.card_data.sound  # optional top-level zap; impacts are in seq

	eff.execute(ctx.battle_scene.api)
	return true

func activate_sim(_ctx: CardActionContextSim) -> bool:
	return true

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
