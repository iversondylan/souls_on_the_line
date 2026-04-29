class_name AbsorbStatusDepiction
extends StatusDepiction


func get_key(event_data: Dictionary) -> String:
	return get_token_key(event_data)


func get_key_prefix(event_data: Dictionary) -> String:
	return get_key(event_data)


func build_fx_commands(event_data: Dictionary) -> Array[Dictionary]:
	var key := get_key(event_data)
	if key.is_empty():
		return []

	var op := int(event_data.get(Keys.OP, 0))
	if op == int(Status.OP.REMOVE):
		return [StatusDepiction.clear_persistent_fx(key, 0.06)]

	var target_id := int(event_data.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		return []

	return [
		StatusDepiction.ensure_persistent_fx(
			target_id,
			key,
			FxLibrary.FX_LIQUID_GLASS_SQUIRM,
			0.15,
			1.08
		)
	]
