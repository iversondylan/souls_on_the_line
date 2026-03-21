# attack_action.gd
extends CardAction

@export var base_damage: int = 5
@export var attack_count: int = 1
@export var sound: Sound = preload("res://audio/fireball_impact.tres")

#func activate(ctx: CardActionContext) -> bool:
	#var targets := ctx.resolved_target.fighters
	#if targets.is_empty():
		#return false
#
	#var attacker := ctx.player
	#var damage := attacker.modifier_system.get_modified_value(
		#base_damage,
		#Modifier.Type.DMG_DEALT
	#)
#
	#var damage_effect := DamageEffect.new()
	#damage_effect.source = attacker
	#damage_effect.targets = targets
	#damage_effect.n_damage = damage
	#damage_effect.sound = sound
	#damage_effect.execute(ctx.battle_scene.api)
#
	#return true

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null or ctx.resolved == null:
		return false

	var source_id := int(ctx.source_id)
	if source_id <= 0:
		return false

	var targets := ctx.target_ids
	if targets.is_empty():
		return false

	var n_hits := maxi(int(attack_count), 1)
	var any := false

	for tid in targets:
		var target_id := int(tid)
		if target_id <= 0:
			continue

		# Apply multiple hits (future: could become AttackSequence instead)
		for _i in range(n_hits):
			var d := DamageContext.new()
			d.source_id = source_id
			d.target_id = target_id
			d.base_amount = int(base_damage)

			# Let SIM modifiers do their thing (defaults are already DMG_DEALT/DMG_TAKEN)
			d.deal_modifier_type = int(Modifier.Type.DMG_DEALT)
			d.take_modifier_type = int(Modifier.Type.DMG_TAKEN)

			# Optional: tags for downstream procs/logging
			# d.tags = [&"card_attack"]

			ctx.api.resolve_damage_immediate(d)
			any = true

		# For card-play logging / debugging
		if !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	return any

func description_arity() -> int:
	return 1

#func get_description_values(ctx: CardActionContext) -> Array:
	#var base := base_damage
	#if ctx.player:
		#base = ctx.player.modifier_system.get_modified_value(base, Modifier.Type.DMG_DEALT)
	#elif ctx.player_data:
		#base = base_damage
	#if ctx.resolved_target and !ctx.resolved_target.fighters.is_empty():
		#var target := ctx.resolved_target.fighters[0]
		#if target and target.modifier_system:
			#base = target.modifier_system.get_modified_value(base, Modifier.Type.DMG_TAKEN)
	#return [base]
