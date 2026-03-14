# beat_scheduler.gd

class_name BeatScheduler extends RefCounted

enum Mode { FREE, RELATIVE, GRID }

# Relative durations in quarter-notes (used when Mode.RELATIVE)
var rel_defaults := {
	BattleEvent.Type.STRIKE: 1.0,
	BattleEvent.Type.SUMMONED: 1.0,
	BattleEvent.Type.DIED: 1.0,
	BattleEvent.Type.FADED: 1.0,
	BattleEvent.Type.STATUS: 1.0,

	# NEW
	BattleEvent.Type.DAMAGE_APPLIED: 1.0,
}

# You can override per arcanum/card later (same as you started)
var override_by_arcanum_id: Dictionary = {}
var override_by_card_name: Dictionary = {}

func mode_for_beat(beat: Array, is_player_turn: bool, is_player_actor: bool) -> int:
	if beat == null or beat.is_empty():
		return Mode.FREE

	if _contains_type(beat, BattleEvent.Type.PLAYER_INPUT_REACHED):
		return Mode.FREE

	if is_player_turn and is_player_actor:
		if _contains_type(beat, BattleEvent.Type.CARD_PLAYED) or _contains_type(beat, BattleEvent.Type.END_TURN_PRESSED):
			return Mode.FREE
		if _contains_any(beat, [BattleEvent.Type.STRIKE, BattleEvent.Type.SUMMONED, BattleEvent.Type.DIED, BattleEvent.Type.FADED, BattleEvent.Type.STATUS, BattleEvent.Type.DAMAGE_APPLIED]):
			return Mode.RELATIVE

	if _contains_type(beat, BattleEvent.Type.ACTOR_BEGIN) and !is_player_actor:
		return Mode.GRID

	var marker := _find_marker(beat)
	if marker == null:
		return Mode.FREE

	return Mode.RELATIVE

func quarters_for_beat(beat: Array[BattleEvent]) -> float:
	if beat == null or beat.is_empty():
		return 0.0

	var marker := _find_marker(beat)
	if marker == null:
		return 0.0

	var q := float(rel_defaults.get(int(marker.type), 0.0))

	# Optional overrides
	if int(marker.type) == BattleEvent.Type.ARCANUM_PROC:
		var aid: StringName = marker.data.get(Keys.ARCANUM_ID, &"") if marker.data else &""
		if aid != &"" and override_by_arcanum_id.has(aid):
			q = float(override_by_arcanum_id[aid])

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

func _contains_type(beat: Array[BattleEvent], t: int) -> bool:
	for e in beat:
		if e != null and int(e.type) == t:
			return true
	return false

func _contains_any(beat: Array[BattleEvent], types: Array[int]) -> bool:
	for e in beat:
		if e == null:
			continue
		if types.has(int(e.type)):
			return true
	return false
