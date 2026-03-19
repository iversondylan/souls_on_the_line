# director_action.gd

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

# For strike actions this will usually be AttackPresentationInfo.
# For other kinds it can stay null or use another info type later.
var presentation: RefCounted = null

var event: BattleEvent = null

# IMPORTANT: untyped Array, not Array[BattleEvent]
var payload: Array = []

var label: String = ""






#class_name DirectorAction extends RefCounted

## One enum entry for each type of action that may contain
## information derived from the raw event stream rather
## than just the raw events themselves.
## The raw events must be issued either within an the corresponding
## DirectorAction (such as a DAMAGE BattleEvent within an IMPACT DirectorAction),
## or within a separate DirectorAction issued at the same time (such as
## DAMAGE event within a FIRE action issued at the same time as an IMPACT
## action -> FIRE controls the actor's movement, IMPACT controls the target's
## movement, DAMAGE controls the update to the target's health).
## Therefore DirectorActions containing no events are cosmetic-only.
## And if two DirectorActions are issued at the same time, it won't
## Matter which of them contains the BattleEvents, because the
## Directoractions themselves are controlling the animations whereas
## the BattleEvents are actually changing the state of the view.

#enum Type {
	#NONE,
	#GENERIC,
	#FOCUS,
	#CLEAR_FOCUS,
	#MELEE_WINDUP,
	#MELEE_STRIKE,
	#RANGED_WINDUP,
	#RANGED_FIRE,
	#IMPACT,
	#DELAY,
	#SUMMON_WINDUP,
	#SUMMON,
	#STATUS_WINDUP,
	#STATUS,
	#DEATH,
#}
#
#var type: int = Type.NONE
#
#var t_start: float = 0.0
#var tempo: float = 120.0
#var presentation: RefCounted = null
#var index := 0
#
#var events: Array[BattleEvent] = []
#
#var label: String = ""
