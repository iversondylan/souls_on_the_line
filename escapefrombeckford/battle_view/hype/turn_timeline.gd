# turn_timeline.gd

class_name TurnTimeline extends RefCounted

var actor_id: int = 0
var group_index: int = -1
var is_player: bool = false

var action_kind: StringName = &""	# "attack", "summon", "status", etc.
var beats: Array[TurnBeat] = []
var trailing_events: Array[BattleEvent] = []
