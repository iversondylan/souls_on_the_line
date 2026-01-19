# spacetime_warp_action.gd
extends CardAction

func activate(ctx: CardActionContext) -> bool:
	if !ctx or !ctx.battle_scene or !ctx.resolved_target:
		return false
	
	var targets := ctx.resolved_target.fighters
	if targets.is_empty():
		return false
	
	var actor := targets[0]
	if !actor:
		return false
	
	# Move is handled at the BattleScene/BattleGroup level now.
	# BattleScene will find the actor's parent BattleGroup and dispatch.
	var move := MoveEffect.new()
	move.actor = actor
	move.move_type = MoveEffect.MoveType.TRAVERSE_PLAYER
	move.can_restore_turn = true
	# Optional: if you add sound to MoveEffect later, you can pass it here.
	# move.sound = ctx.card_data.sound
	
	ctx.battle_scene.execute_move(move)
	
	# SFX can be played inside execute_move / BattleGroup.execute_move if desired,
	# or leave it silent for now.
	# SFXPlayer.play(ctx.card_data.sound)

	return true

func description_arity() -> int:
	return 0

func get_description_values(_ctx: CardActionContext) -> Array:
	return []
