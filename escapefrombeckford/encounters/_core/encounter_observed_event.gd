class_name EncounterObservedEvent extends RefCounted

var name: StringName = &""
var battle_event_type: int = -1
var seq: int = 0
var actor_id: int = 0
var source_id: int = 0
var target_id: int = 0
var group_index: int = -1
var active_id: int = 0
var card_id: StringName = &""
var card_uid: StringName = &""
var card_proto_path: String = ""
var insert_index: int = -1
var target_ids: PackedInt32Array = PackedInt32Array()
var summoned_ids: PackedInt32Array = PackedInt32Array()
var data: Dictionary = {}
