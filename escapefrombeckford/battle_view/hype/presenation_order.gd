# presenation_order.gd

class_name PresentationOrder extends RefCounted

# A PresentationOrder starts a presentational behavior at a cue beat. 
# It does not own the full lifetime of all resulting visuals, and 
# it does not imply that later cues must wait for it to finish.

enum Kind {
	FOCUS,
	CLEAR_FOCUS,
	MELEE_WINDUP,
	MELEE_STRIKE,
	RANGED_WINDUP,
	RANGED_FIRE,
	IMPACT,
	SUMMON_WINDUP,
	SUMMON_POP,
	STATUS_WINDUP,
	STATUS_POP,
	DEATH,
	FADE,
	GROUP_LAYOUT,
}

var kind: int = Kind.FOCUS
var actor_id: int = 0
var target_ids: Array[int] = []
var visual_sec: float = 0.0
var meta: Dictionary = {}
