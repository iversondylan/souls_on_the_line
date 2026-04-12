# battle_event.gd
class_name BattleEvent
extends RefCounted

# Keep this broad; you'll add more event types over time.
enum Type {
	SCOPE_BEGIN,
	SCOPE_END,
	
	SPAWNED,
	FORMATION_SET,
	
	TURN_GROUP_BEGIN,
	TURN_GROUP_END,
	
	ACTOR_BEGIN,
	ACTOR_END,
	ARCANA_PROC,
	ARCANUM_PROC,
	CARD_PLAYED,
	
	DAMAGE_APPLIED,
	HEAL_APPLIED,
	STATUS,
	SUMMONED,
	MOVED,
		TARGETED,
		STRIKE,
		CLEAVE,
		REMOVED,
	CARD_MUTATED,
	
	DEBUG,
	SET_INTENT,
	STATUS_CHANGED,
	PLAYER_INPUT_REACHED,
	END_TURN_PRESSED,
	DISCARD_REQUESTED,
	DISCARD_RESOLVED,
	SUMMON_RESERVE_RELEASED,
	TURN_STATUS,
	MANA,
	VICTORY,
	DEFEAT,
	DRAW_CARDS,
	DISCARD_CARDS,
	CHANGE_MAX_HEALTH,
	MODIFY_BATTLE_CARD,
}

var defines_beat: bool = false

var seq: int = 0					# monotonic per battle
var battle_tick: int = 0			# optional; can equal seq for now

var turn_id: int = 0
var group_index: int = -1
var active_actor_id: int = 0

var scope_id: int = 0
var parent_scope_id: int = 0
var scope_kind: int = -1 # an enum value from Scope.Kind
var type: int = Type.DEBUG

# Data payload (keep flexible)
var data: Dictionary = {}

func _init(_type: int = Type.DEBUG) -> void:
	type = _type
