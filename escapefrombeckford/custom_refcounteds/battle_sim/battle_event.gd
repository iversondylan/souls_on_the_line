# battle_event.gd
class_name BattleEvent extends RefCounted

enum Type {
	CARD_PLAYED,
	DAMAGE_APPLIED,
	HEAL_APPLIED,
	STATUS_APPLIED,
	STATUS_REMOVED,
	SUMMONED,
	MOVED,
	ATTACK_SEQUENCE_STARTED,
	ATTACK_HIT,
	UNIT_DIED,
	TURN_COUNTERS_CHANGED,
}

var type: int = -1
var t: int = 0 # monotonic sequence number for stable ordering (optional)

var source_id: int = 0
var target_id: int = 0

var amount: int = 0
var status_id: StringName = &""
var duration: int = 0
var intensity: int = 0

var card_id: int = 0
var card_type: int = -1

var summoned_id: int = 0
var group_index: int = -1
var insert_index: int = -1
var proto_path: String = "" # optional: for live spawn visuals

var params: Dictionary = {} # flexible: crit flags, tags, etc.
