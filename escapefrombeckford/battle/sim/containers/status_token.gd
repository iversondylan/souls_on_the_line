# status_token.gd

class_name StatusToken extends RefCounted

var id: StringName
var token_id: int = 0
var pending: bool = false
var stacks: int = 1
var data: Dictionary = {}

func _init(_id: StringName = &"") -> void:
id = _id

func clone():
var s: Variant = get_script().new(id)
s.token_id = token_id
s.pending = pending
s.stacks = stacks
s.data = data.duplicate(true)
return s
