# move_effect.gd
class_name MoveEffect extends Effect

enum MoveType {
	TRAVERSE_PLAYER,
	MOVE_TO_FRONT,
	MOVE_TO_BACK,
	SWAP_WITH_TARGET,
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

func execute(_api: BattleAPI) -> void:
	if not battle_scene or not actor:
		return

	battle_scene.execute_move(self)

	if sound:
		SFXPlayer.play(sound)
