class_name TransformerSourceRef
extends RefCounted


var source_kind: StringName = &""
var source_owner_id: int = 0
var source_group_index: int = -1
var source_id: StringName = &""
var source_instance_id: int = 0


func _init(
	_source_kind: StringName = &"",
	_source_owner_id: int = 0,
	_source_group_index: int = -1,
	_source_id: StringName = &"",
	_source_instance_id: int = 0
) -> void:
	source_kind = StringName(_source_kind)
	source_owner_id = int(_source_owner_id)
	source_group_index = int(_source_group_index)
	source_id = StringName(_source_id)
	source_instance_id = int(_source_instance_id)


func is_valid() -> bool:
	return source_kind != &"" and source_owner_id > 0 and source_id != &""


func clone():
	return get_script().new(
		source_kind,
		source_owner_id,
		source_group_index,
		source_id,
		source_instance_id
	)


static func for_status_token(
	source_owner_id: int,
	source_group_index: int,
	status_id: StringName,
	token_id: int
) -> TransformerSourceRef:
	return TransformerSourceRef.new(
		TransformerRecord.SOURCE_KIND_STATUS_TOKEN,
		source_owner_id,
		source_group_index,
		status_id,
		token_id
	)


static func for_arcanum_entry(
	source_owner_id: int,
	source_group_index: int,
	arcanum_id: StringName
) -> TransformerSourceRef:
	return TransformerSourceRef.new(
		TransformerRecord.SOURCE_KIND_ARCANUM_ENTRY,
		source_owner_id,
		source_group_index,
		arcanum_id,
		0
	)
