class_name ResonanceSpikeStatusDepiction
extends StatusDepiction

const CENTER_Y_RATIO := 0.75
const SCALE := 0.9
const FADE_SECONDS := 0.06
const STATUS_ID := &"resonance_spike"


func get_key(event_data: Dictionary) -> String:
	if bool(event_data.get(Keys.IS_PROJECTED, false)):
		var target_id := int(event_data.get(Keys.TARGET_ID, 0))
		var token_id := int(event_data.get(Keys.AFTER_TOKEN_ID, 0))
		if token_id <= 0:
			token_id = int(event_data.get(Keys.BEFORE_TOKEN_ID, 0))
		if target_id > 0 and token_id > 0:
			return StatusDepiction.make_projection_key(STATUS_ID, target_id, token_id)
	return get_token_key(event_data)


func get_key_prefix(event_data: Dictionary) -> String:
	return get_key(event_data)


func build_fx_commands(event_data: Dictionary) -> Array[StatusDepictionFxCommand]:
	var key := get_key(event_data)
	if key.is_empty():
		return []

	var op := int(event_data.get(Keys.OP, 0))
	if op == int(Status.OP.REMOVE):
		return [StatusDepiction.clear_persistent_fx(key, FADE_SECONDS)]

	var target_id := int(event_data.get(Keys.TARGET_ID, 0))
	if target_id <= 0:
		return []

	return [
		StatusDepiction.ensure_persistent_fx(
			target_id,
			key,
			FxLibrary.FX_RESONANCE_SPIKE_RIPPLES,
			FADE_SECONDS,
			SCALE,
			CENTER_Y_RATIO
		)
	]
