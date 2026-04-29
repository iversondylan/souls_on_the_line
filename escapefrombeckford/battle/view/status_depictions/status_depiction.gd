class_name StatusDepiction
extends Resource

const MARKER_KIND := &"marker_kind"
const MARKER_TARGETED := &"targeted"
const MARKER_DANGER_ZONE := &"danger_zone"
const FX_OP := &"fx_op"
const FX_OP_ENSURE_PERSISTENT := &"ensure_persistent_fx"
const FX_OP_CLEAR_PERSISTENT := &"clear_persistent_fx"
const FX_KEY := &"fx_key"
const FX_ID := &"fx_id"
const FX_FADE_IN := &"fx_fade_in"
const FX_FADE_OUT := &"fx_fade_out"
const FX_SCALE := &"fx_scale"


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


func get_token_key(event_data: Dictionary) -> String:
	var status_id := String(event_data.get(Keys.STATUS_ID, &""))
	var token_id := int(event_data.get(Keys.AFTER_TOKEN_ID, 0))
	if token_id <= 0:
		token_id = int(event_data.get(Keys.BEFORE_TOKEN_ID, 0))
	if status_id.is_empty() or token_id <= 0:
		return get_target_key_prefix(event_data)
	return "%s:token:%d" % [status_id, token_id]


func build_markers(_event_data: Dictionary) -> Array[Dictionary]:
	return []


func build_fx_commands(_event_data: Dictionary) -> Array[Dictionary]:
	return []


static func marker(target_id: int, marker_kind: StringName) -> Dictionary:
	return {
		Keys.TARGET_ID: int(target_id),
		MARKER_KIND: marker_kind,
	}


static func ensure_persistent_fx(
	target_id: int,
	key: String,
	fx_id: StringName,
	fade_in := 0.06,
	scale := 1.05
) -> Dictionary:
	return {
		FX_OP: FX_OP_ENSURE_PERSISTENT,
		Keys.TARGET_ID: int(target_id),
		FX_KEY: key,
		FX_ID: fx_id,
		FX_FADE_IN: fade_in,
		FX_SCALE: scale,
	}


static func clear_persistent_fx(key: String, fade_out := 0.06) -> Dictionary:
	return {
		FX_OP: FX_OP_CLEAR_PERSISTENT,
		FX_KEY: key,
		FX_FADE_OUT: fade_out,
	}
