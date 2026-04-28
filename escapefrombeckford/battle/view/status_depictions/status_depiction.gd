class_name StatusDepiction
extends Resource

const MARKER_KIND := &"marker_kind"
const MARKER_TARGETED := &"targeted"
const MARKER_DANGER_ZONE := &"danger_zone"


func get_key(event_data: Dictionary) -> String:
	return get_target_key_prefix(event_data)


func get_key_prefix(event_data: Dictionary) -> String:
	return get_source_key_prefix(event_data)


func get_source_key_prefix(event_data: Dictionary) -> String:
	var status_id := String(event_data.get(Keys.STATUS_ID, &""))
	var source_id := int(event_data.get(Keys.SOURCE_ID, 0))
	return "%s:%d" % [status_id, source_id]


func get_target_key_prefix(event_data: Dictionary) -> String:
	var source_prefix := get_source_key_prefix(event_data)
	var target_id := int(event_data.get(Keys.TARGET_ID, 0))
	return "%s:%d" % [source_prefix, target_id]


func build_markers(_event_data: Dictionary) -> Array[Dictionary]:
	return []


static func marker(target_id: int, marker_kind: StringName) -> Dictionary:
	return {
		Keys.TARGET_ID: int(target_id),
		MARKER_KIND: marker_kind,
	}
