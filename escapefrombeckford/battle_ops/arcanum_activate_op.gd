# arcanum_activate_op.gd

class_name ArcanumActivateOp extends BattleOp

var arcanum: Arcanum
var display: ArcanumDisplay

func _init(a: Arcanum, d: ArcanumDisplay) -> void:
	arcanum = a
	display = d

func run(api: LiveBattleAPI, _runner: BattleResolutionRunner) -> Variant:
	if !api or !arcanum:
		return null
	return api._run_arcanum_activate_op(arcanum, display) # <- Error at (15, 12): Cannot get return value of call to "_run_arcanum_activate_op()" because it returns "void". 
