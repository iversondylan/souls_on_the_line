# attack_now_action.gd
extends CardAction

@export var attacks: int = 1
@export var param_models: Array[ParamModel]

func activate(ctx: CardActionContext) -> bool:
	# Keep the same guard you had: require at least one resolved fighter.
	# (Even though the sequence itself doesn't use resolved targets directly.)
	var resolved_fighters := ctx.resolved_target.fighters
	if resolved_fighters.is_empty():
		return false
	
	# PRESERVE your prior semantics: "attacker" is the first resolved fighter.
	# If you later decide this should always be the player, change to:
	# var attacker: Fighter = ctx.player
	var attacker: Fighter = resolved_fighters[0]
	if !attacker:
		return false
	
	# Build NPCAIContext for the sequence.
	var ai_ctx := NPCAIContext.new()
	ai_ctx.combatant = attacker
	ai_ctx.battle_scene = ctx.battle_scene
	if !ai_ctx.battle_scene:
		return false
	
	# Card-generated sequences get a fresh, non-persistent state bucket by default.
	ai_ctx.state = {}
	ai_ctx.params = {}
	ai_ctx.forecast = false
	
	# Params consumed by NPCAttackSequence.
	var base_damage: int = attacker.combatant_data.max_mana_red + 1
	ai_ctx.params[NPCKeys.DAMAGE] = attacker.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	ai_ctx.params[NPCKeys.STRIKES] = attacks
	ai_ctx.params[NPCKeys.TARGET_TYPE] = NPCAttackSequence.TARGET_STANDARD
	for model in param_models:
		model.change_params(ai_ctx)
	# Run sequence
	var seq := NPCAttackSequence.new()
	seq.sound = ctx.card_data.sound
	seq.execute(ai_ctx, Callable(self, "_on_card_attack_sequence_done"))
	
	return true

func _on_card_attack_sequence_done() -> void:
	pass

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
