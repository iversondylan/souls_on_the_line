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
var stacks: int = 0
var pending: bool = false

# "what happened"
var op := Status.OP.APPLY
var delta_stacks := 0 # relevant only for CHANGED

var before_stacks := 0
var after_stacks := 0
var before_pending: bool = false
var after_pending: bool = false
var before_token_id: int = 0
var after_token_id: int = 0

# optional tags
var tags: Array[StringName] = []
var reason: String = ""
var presentation_hint: StringName = &"standalone"
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""

# results (filled by API)
var applied: bool = false
