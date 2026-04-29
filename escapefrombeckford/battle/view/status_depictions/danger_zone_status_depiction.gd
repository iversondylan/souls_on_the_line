class_name DangerZoneStatusDepiction
extends StatusDepiction


func get_key(event_data: Dictionary) -> String:
	var status_id: StringName = event_data.get(Keys.STATUS_ID, &"")
	var source_id := int(event_data.get(Keys.SOURCE_ID, 0))
	var token_id := int(event_data.get(Keys.AFTER_TOKEN_ID, 0))
	if token_id <= 0:
		token_id = int(event_data.get(Keys.BEFORE_TOKEN_ID, 0))
	if status_id == &"" or source_id <= 0 or token_id <= 0:
		return get_target_key_prefix(event_data)
	return StatusDepiction.make_token_key(status_id, token_id, source_id)


func get_key_prefix(event_data: Dictionary) -> String:
	return get_source_key_prefix(event_data)


func build_markers(event_data: Dictionary) -> Array[StatusDepictionMarkerCommand]:
	var markers: Array[StatusDepictionMarkerCommand] = []
	var target_id := int(event_data.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		return markers

	markers.append(StatusDepiction.marker(target_id, StatusDepiction.MARKER_TARGETED))
	markers.append(StatusDepiction.marker(target_id, StatusDepiction.MARKER_DANGER_ZONE))

	var status_data = event_data.get(Keys.STATUS_DATA, {})
	if !(status_data is Dictionary):
		return markers

	var adjacent_ids := _coerce_int_array(status_data.get(Keys.DANGER_ZONE_ADJACENT_TARGET_IDS, PackedInt32Array()))
	for adjacent_id in adjacent_ids:
		if int(adjacent_id) > 0:
			markers.append(StatusDepiction.marker(int(adjacent_id), StatusDepiction.MARKER_DANGER_ZONE))

	return markers


func _coerce_int_array(value: Variant) -> Array[int]:
	var out: Array[int] = []
	if value is PackedInt32Array:
		for entry in value:
			out.append(int(entry))
	elif value is Array:
		for entry in value:
			out.append(int(entry))
	return out
