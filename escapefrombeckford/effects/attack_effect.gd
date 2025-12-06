class_name AttackEffect
extends Effect

enum RetargetPriority {NONE, FRONT}
var battle_scene: BattleScene
var attacker: Fighter
var n_damage: int = 0
var n_attacks: int = 1
var retarget_priority: RetargetPriority = RetargetPriority.FRONT
var explode: bool = false

func start():
	execute_step()

func execute_step():
	push_error("Must be implemented by subclass")

#func execute():
	#push_error("AttackEffect.execute() must be implemented in subclass.")

#func _get_valid_targets(input_targets: Array[Fighter]) -> Array[Fighter]:
	#if input_targets.size() == 1 and retarget_priority == AttackEffect.RetargetPriority.FRONT:
		#if !input_targets[0] or !input_targets[0].is_alive():
			#var target_battle_group_index: int
			#if attacker.get_parent() is BattleGroupEnemy:
				#target_battle_group_index = 0
			#else:
				#target_battle_group_index = 1
			#return [attacker.battle_scene.get_front_or_focus(target_battle_group_index)]
	#return input_targets

func get_mean_position() -> Vector2:
	print("attack_effect.gd get_mean_position()")
	if !targets:
		return attacker.anchor_position
	var cum_target_position := Vector2.ZERO
	var n_targets: float = float(targets.size())
	for target: Fighter in targets:
		cum_target_position += target.global_position
	return cum_target_position/n_targets #average global position of targets
