class_name AttackEffect
extends Effect

##Standard currently means priority is FOCUS > FRONT
enum TargetType {STANDARD, ALL_OPPONENTS, ALL}
enum RetargetPriority {NONE, FRONT}
var battle_scene: BattleScene
var attacker: Fighter
var n_damage: int = 0
var n_attacks: int = 1
var target_type: TargetType = TargetType.STANDARD
var retarget_priority: RetargetPriority = RetargetPriority.FRONT
var explode: bool = false

func execute():
	execute_step()

func execute_step():
	push_error("Must be implemented by subclass")
	
func get_mean_position() -> Vector2:
	if !targets:
		return attacker.anchor_position
	var cum_target_position := Vector2.ZERO
	var n_targets: float = float(targets.size())
	for target: Fighter in targets:
		cum_target_position += target.global_position
	return cum_target_position/n_targets #average global position of targets
