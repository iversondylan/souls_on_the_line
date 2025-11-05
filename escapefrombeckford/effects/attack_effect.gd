class_name AttackEffect
extends Effect

#var attacker: Fighter
enum RetargetPriority {NONE, FRONT}
#var targets: Array[Fighter] = []
var attacker: Fighter
var n_damage: int = 0
var n_attacks: int = 1
var retarget_priority: RetargetPriority = RetargetPriority.FRONT
var explode: bool = false

#var tween: Tween

func execute(targets: Array[Fighter]):
	push_error("AttackEffect.execute() must be implemented in subclass.")

#func execute(attacker: Array[Fighter]) -> void:
	#if !attacker:
		#return
	#if targets:
		#attacker[0].attack(targets, n_damage, n_attacks, retarget_priority, explode)
func _get_valid_targets(input_targets: Array[Fighter]) -> Array[Fighter]:
	#var retargeting: bool = false
	if input_targets.size() == 1 and retarget_priority == AttackEffect.RetargetPriority.FRONT:
		if !input_targets[0] or !input_targets[0].is_alive():
			var target_battle_group_index: int
			if attacker.get_parent() is BattleGroupEnemy:
				target_battle_group_index = 0
			else:
				target_battle_group_index = 1
			#retargeting = true
			return [attacker.battle_scene.get_front_or_focus(target_battle_group_index)]
	return input_targets

func get_mean_position(targets: Array[Fighter]) -> Vector2:
	var cum_target_position := Vector2.ZERO
	var n_targets: float = float(targets.size())
	for target: Fighter in targets:
		cum_target_position += target.global_position
	return cum_target_position/n_targets #average global position of targets
