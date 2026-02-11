# status_context.gd
class_name StatusContext
extends RefCounted

var source: Fighter = null
var source_id: int = 0

var target: Fighter = null
var target_id: int = 0

# "what to apply"
var status: Status = null # template (will be duplicated in Live)
var duration: int = 0
var intensity: int = 0

# optional tags
var tags: Array[StringName] = []

# results (filled by API)
var applied: bool = false

func hydrate_ids() -> void:
	if source and source_id == 0:
		source_id = source.combat_id
	if target and target_id == 0:
		target_id = target.combat_id
