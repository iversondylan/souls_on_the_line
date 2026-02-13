# attack_now_effect.gd
class_name AttackNowEffect
extends Effect

@export var attacks: int = 1
@export var param_models: Array[ParamModel] = []

# Optional
var attacker: Fighter = null
var base_damage_override: int = -1
var use_base_damage_override: bool = false

func execute(api: BattleAPI) -> void:
	if !api:
		return

	# Attacker resolution rule:
	# 1) explicit attacker field wins
	# 2) otherwise first target in targets
	var a: Fighter = attacker
	if !a and targets and !targets.is_empty():
		a = targets[0]

	if !a:
		return

	var ctx := AttackNowContext.new()
	ctx.attacker = a
	ctx.attacker_id = a.combat_id
	ctx.strikes = attacks
	ctx.param_models = param_models
	ctx.sound = sound

	ctx.use_base_damage_override = use_base_damage_override
	ctx.base_damage = base_damage_override

	api.resolve_attack_now(ctx)
