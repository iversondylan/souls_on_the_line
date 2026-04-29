class_name SimpleTokenFxStatusDepiction
extends StatusDepiction

@export var fx_id: StringName = &""
@export var fade_in: float = 0.15
@export var fade_out: float = 0.06
@export var scale: float = 1.05
@export var center_y_ratio: float = 0.5


func get_key(event_data: Dictionary) -> String:
	return get_token_key(event_data)


func get_key_prefix(event_data: Dictionary) -> String:
	return get_key(event_data)


func build_fx_commands(event_data: Dictionary) -> Array[StatusDepictionFxCommand]:
	var key := get_key(event_data)
	if key.is_empty() or fx_id == &"":
		return []

	var op := int(event_data.get(Keys.OP, 0))
	if op == int(Status.OP.REMOVE):
		return [StatusDepiction.clear_persistent_fx(key, fade_out)]

	var target_id := int(event_data.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		return []

	return [
		StatusDepiction.ensure_persistent_fx(
			target_id,
			key,
			fx_id,
			fade_in,
			scale,
			center_y_ratio
		)
	]
