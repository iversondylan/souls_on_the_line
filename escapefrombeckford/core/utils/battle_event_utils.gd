# battle_event_utils.gd

class_name BattleEventUtils extends RefCounted

static func beat_root_kind(beat: Array[BattleEvent]) -> int:
	if beat.is_empty():
		return -1
	return int(beat[0].scope_kind) if beat[0] != null else -1

static func beat_root_label(beat: Array[BattleEvent]) -> String:
	if beat.is_empty():
		return ""
	var e := beat[0]
	if e == null:
		return ""
	return String(e.data.get(Keys.SCOPE_LABEL, ""))
