# beat_scheduler.gd

class_name BeatScheduler extends RefCounted

# Defaults in quarter-notes
var defaults := {
	BattleEvent.Type.ARCANUM_PROC: 1.0,
	BattleEvent.Type.STRIKE: 0.5,
	BattleEvent.Type.DAMAGE_APPLIED: 0.0,
	BattleEvent.Type.STATUS: 0.0,
	BattleEvent.Type.SUMMONED: 1.0,
	BattleEvent.Type.DIED: 1.0,
	BattleEvent.Type.FADED: 0.5,
	BattleEvent.Type.ACTOR_BEGIN: 0.0,
	BattleEvent.Type.ACTOR_END: 0.0,
	BattleEvent.Type.TURN_STATUS: 0.0,
	BattleEvent.Type.CARD_PLAYED: 0.0,
}

# Optional per-id overrides:
# eg scheduler.override_by_arcanum_id[&"unruly_pyric_wraps"] = 0.5
var override_by_arcanum_id: Dictionary = {} # StringName -> float
var override_by_card_name: Dictionary = {}  # String -> float

func quarters_for_beat(beat: Array[BattleEvent]) -> float:
	if beat == null or beat.is_empty():
		return 0.0

	var marker := _find_marker(beat)
	if marker == null:
		return 0.0

	# type-based default
	var q := float(defaults.get(int(marker.type), 0.0))

	# example: arcanum overrides
	if int(marker.type) == BattleEvent.Type.ARCANUM_PROC:
		var aid : StringName = marker.data.get(Keys.ARCANUM_ID, &"") if marker.data else &""
		if aid != &"" and override_by_arcanum_id.has(aid):
			q = float(override_by_arcanum_id[aid])

	# example: card overrides
	if int(marker.type) == BattleEvent.Type.CARD_PLAYED:
		var cname := String(marker.data.get(Keys.CARD_NAME, "")) if marker.data else ""
		if cname != "" and override_by_card_name.has(cname):
			q = float(override_by_card_name[cname])

	return maxf(q, 0.0)

func _find_marker(beat: Array[BattleEvent]) -> BattleEvent:
	for e in beat:
		if e != null and e.defines_beat:
			return e
	return null
