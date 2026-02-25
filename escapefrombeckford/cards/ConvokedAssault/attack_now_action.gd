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

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []

func activate_sim(ctx: CardActionContextSim) -> bool:
	if ctx == null or ctx.api == null or ctx.resolved == null:
		return false

	# You currently choose attacker as first resolved fighter (live); SIM needs an id.
	var attacker_id := 0
	if ctx.resolved.fighter_ids.size() > 0:
		attacker_id = int(ctx.resolved.fighter_ids[0])
	if attacker_id <= 0:
		return false

	var spec := SimAttackSpec.new()
	spec.attacker_id = attacker_id
	spec.strikes = maxi(int(attacks), 1)
	spec.base_damage = 0 # if AttackNow has its own base; else default 0 and let param models set it
	spec.params = {
		NPCKeys.STRIKES: spec.strikes,
		NPCKeys.TARGET_TYPE: NPCAttackSequence.TARGET_STANDARD,
		# NPCKeys.ATTACK_MODE can be set by param models
	}

	# Apply your param models (they already speak ctx.params style)
	var ai_ctx := NPCAIContext.new()
	ai_ctx.api = ctx.api
	ai_ctx.combatant = null
	ai_ctx.combatant_state = ctx.api.state.get_unit(attacker_id)
	#ai_ctx.combatant_data = api. #ctx.resolved.combatant_datas[0]
	ai_ctx.battle_scene = null
	ai_ctx.state = {} # if needed
	ai_ctx.params = spec.params
	ai_ctx.forecast = false

	if param_models:
		for m in param_models:
			if m:
				m.change_params_sim(ai_ctx)

	# Pull any values param models might set
	spec.strikes = int(spec.params.get(NPCKeys.STRIKES, spec.strikes))
	spec.base_damage = int(spec.params.get(NPCKeys.DAMAGE, spec.base_damage))
	print("attack_now_action.gd activate_sim() base_damage: ", spec.base_damage)
	return ctx.api.resolve_attack(spec)
