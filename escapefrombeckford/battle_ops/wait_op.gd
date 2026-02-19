# wait_op.gd

class_name WaitOp extends BattleOp

const ID := &"WAIT_OP"

var duration_sec: float = 0.0

func _init(d: float = 0.0) -> void:
	duration_sec = maxf(d, 0.0)

func get_id() -> StringName:
	return ID

func run(_api: LiveBattleAPI, runner: BattleResolutionRunner) -> Variant:
	if duration_sec <= 0.0:
		return null
	return runner.get_tree().create_timer(duration_sec).timeout
