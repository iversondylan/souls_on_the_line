# status_token_context.gd
class_name StatusTokenContext
extends RefCounted

var id: String = ""
var duration: int = 0
var intensity: int = 0

# Owner reference (either node or id, or both)
var owner: Node = null
var owner_id: int = -1

func _init() -> void:
	pass
