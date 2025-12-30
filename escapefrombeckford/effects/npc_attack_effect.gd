# npc_attack_effect.gd
class_name NPCAttackEffect extends Effect
## or extends Effect if you need it in your pipeline

enum TargetType {STANDARD, ALL_OPPONENTS, ALL}

var ctx: NPCAIContext
var target_type: TargetType = TargetType.STANDARD
var n_damage: int = 0
var n_attacks: int = 1
var explode_on_finish: bool = false


func _init(_ctx: NPCAIContext) -> void:
	ctx = _ctx


func execute() -> void:
	_execute_step()


func _execute_step() -> void:
	push_error("NPCAttackEffect._execute_step() must be implemented")


func _finish_attack() -> void:
	var fighter := ctx.combatant
	if !fighter:
		return

	var tween := fighter.create_tween().set_trans(Tween.TRANS_QUINT)

	if explode_on_finish:
		tween.tween_callback(func(): fighter.die())
	else:
		tween.tween_property(
			fighter,
			"position",
			fighter.anchor_position,
			0.4
		)

	tween.tween_callback(func():
		fighter.info_visible(true)
		fighter.resolve_action()
	)
