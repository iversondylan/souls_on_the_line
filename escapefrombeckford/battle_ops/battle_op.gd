# battle_op.gd

class_name BattleOp extends RefCounted

# Return value can be:
# - null (sync)
# - a Signal (awaitable)
# - a GDScriptFunctionState (awaitable)
func run(_api: LiveBattleAPI, _runner: BattleResolutionRunner) -> Variant:
	return null

func get_id() -> StringName:
	return &""
