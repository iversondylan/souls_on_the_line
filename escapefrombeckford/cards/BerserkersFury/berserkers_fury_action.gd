extends CardAction

@export var bonus_damage: int = 2
@export var attacks: int = 1
@export var melee_impact_sound: Sound = preload("res://audio/aoe_explosion.tres")

func activate(ctx: CardActionContext) -> bool:
	var attackers := ctx.resolved_target.fighters
	if attackers.is_empty():
		return false
	
	
	var attacker: Fighter = attackers[0]
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
	
	var base_damage := attacker.combatant_data.max_mana_red + bonus_damage
	var final_damage := attacker.modifier_system.get_modified_value(base_damage, Modifier.Type.DMG_DEALT)
	# Params consumed by NPCAttackSequence.
	ai_ctx.params[NPCKeys.ATTACK_MODE] = Attack.Mode.MELEE
	ai_ctx.params[NPCKeys.DAMAGE] = final_damage
	ai_ctx.params[NPCKeys.STRIKES] = attacks
	ai_ctx.params[NPCKeys.TARGET_TYPE] = NPCAttackSequence.TARGET_OPPONENTS
	ai_ctx.params[NPCKeys.EXPLODE_ON_FINISH] = true
	
	# Run sequence
	var seq := NPCAttackSequence.new()
	seq.melee_impact_sound = melee_impact_sound
	seq.execute(ai_ctx, Callable(self, "_on_card_attack_sequence_done"))
	
	return true

func _on_card_attack_sequence_done() -> void:
	pass


func description_arity() -> int:
	return 1


func get_description_values(ctx: CardActionContext) -> Array:
	# Case 1: hovering a valid ally → show fully modified value
	if ctx.resolved_target and !ctx.resolved_target.fighters.is_empty():
		var ally: Fighter = ctx.resolved_target.fighters[0]

		var base_damage := ally.combatant_data.max_mana_red + bonus_damage
		var modified_damage := ally.modifier_system.get_modified_value(
			base_damage,
			Modifier.Type.DMG_DEALT
		)

		return [modified_damage]

	# Case 2: no ally hovered → baseline preview (no modifiers)
	# Prefer player_data if player is not instantiated
	if ctx.player:
		return [ctx.player.combatant_data.max_mana_red + bonus_damage]

	if ctx.player_data:
		return [ctx.player_data.max_mana_red + bonus_damage]

	# Absolute fallback (should be rare)
	return [bonus_damage]
