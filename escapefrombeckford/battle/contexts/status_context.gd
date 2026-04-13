# status_context.gd
class_name StatusContext
extends RefCounted

var actor_id: int = 0

#var source: Fighter = null
var source_id: int = 0

#var target: Fighter = null
var target_id: int = 0
var target_ids: PackedInt32Array = PackedInt32Array()

# "what to apply"
var status_id: StringName = &""
var duration: int = 0
var intensity: int = 0
var pending: bool = false



# "what happened"
var op := Status.OP.APPLY
var delta_intensity := 0 # relevant only for CHANGED
var delta_duration := 0 # relevant only for CHANGED

var before_intensity := 0
var before_duration := 0
var after_intensity := 0
var after_duration := 0
var before_pending: bool = false
var after_pending: bool = false

# optional tags
var tags: Array[StringName] = []
var reason: String = ""
var presentation_hint: StringName = &"standalone"
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""

# results (filled by API)
var applied: bool = false

#func hydrate_ids() -> void:
	#if source and source_id == 0:
		#source_id = source.combat_id
	#if target and target_id == 0:
		#target_id = target.combat_id
