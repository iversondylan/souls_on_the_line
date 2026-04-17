class_name ProjectionSourceEntry extends RefCounted

var source_kind: StringName = &""
var source_owner_id: int = 0
var source_id: StringName = &""


func _init(
	_source_kind: StringName = &"",
	_source_owner_id: int = 0,
	_source_id: StringName = &""
) -> void:
	source_kind = StringName(_source_kind)
	source_owner_id = int(_source_owner_id)
	source_id = StringName(_source_id)


func is_valid() -> bool:
	return source_kind != &"" and source_owner_id > 0 and source_id != &""


func get_source_key() -> String:
	if !is_valid():
		return ""
	return make_source_key(source_kind, source_owner_id, source_id)


func clone():
	return get_script().new(source_kind, source_owner_id, source_id)


static func make_source_key(
	source_kind: StringName,
	source_owner_id: int,
	source_id: StringName
) -> String:
	if source_kind == &"" or int(source_owner_id) <= 0 or source_id == &"":
		return ""
	return "%s::%s::%s" % [
		String(source_kind),
		str(int(source_owner_id)),
		String(source_id),
	]
