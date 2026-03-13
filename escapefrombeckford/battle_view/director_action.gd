class_name DirectorAction extends RefCounted

enum Phase {
	FOCUS,
	WINDUP,
	FOLLOWTHROUGH,
	RESOLVE,
}

enum ActionKind {
	NONE,
	GENERIC,
	MELEE_STRIKE,
	RANGED_STRIKE,
	SUMMON,
	STATUS,
	DEATH,
}

var phase: int = Phase.FOCUS
var action_kind: int = ActionKind.NONE

var t_rel_sec: float = 0.0
var duration_sec: float = 0.0

var event: BattleEvent = null

# IMPORTANT: untyped Array, not Array[BattleEvent]
var payload: Array = []

var label: String = ""
