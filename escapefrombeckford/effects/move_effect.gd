# move_effect.gd
class_name MoveEffect extends Effect

enum MoveType {
	TRAVERSE_PLAYER,
	MOVE_TO_FRONT,
	MOVE_TO_BACK,
	SWAP_WITH_TARGET,
	SWAP_WITH_ADJACENT,
	INSERT_AT_INDEX
}

@export var move_type: MoveType

# Required parameters
var battle_scene: BattleScene

# Optional parameters
var actor: Fighter
var target: Fighter = null
var index: int = -1

# If true, a fighter with no turn left this group turn
# may be re-added to acting_fighters if moved to a "future" slot.
var can_restore_turn: bool = false

func execute(api: BattleAPI) -> void:
	if !api or !actor:
		return

	var ctx := MoveContext.new()
	ctx.move_type = int(move_type)
	ctx.actor = actor
	ctx.actor_id = actor.combat_id

	if target:
		ctx.target = target
		ctx.target_id = target.combat_id

	ctx.index = index
	ctx.can_restore_turn = can_restore_turn
	ctx.sound = sound

	api.resolve_move(ctx)
