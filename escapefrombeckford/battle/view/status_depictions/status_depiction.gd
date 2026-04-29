class_name StatusDepiction
extends Resource

const StatusDepictionMarkerCommand := preload("res://battle/view/status_depictions/status_depiction_marker_command.gd")
const StatusDepictionFxCommand := preload("res://battle/view/status_depictions/status_depiction_fx_command.gd")

const MARKER_TARGETED := &"targeted"
const MARKER_DANGER_ZONE := &"danger_zone"
const FX_OP_ENSURE_PERSISTENT := &"ensure_persistent_fx"
const FX_OP_CLEAR_PERSISTENT := &"clear_persistent_fx"


func get_key(event_data: Dictionary) -> String:
	return get_target_key_prefix(event_data)


func get_key_prefix(event_data: Dictionary) -> String:
	return get_source_key_prefix(event_data)


func get_source_key_prefix(event_data: Dictionary) -> String:
	var status_id := String(event_data.get(Keys.STATUS_ID, &""))
	var source_id := int(event_data.get(Keys.SOURCE_ID, 0))
	return make_source_key_prefix(status_id, source_id)


func get_target_key_prefix(event_data: Dictionary) -> String:
	var status_id := String(event_data.get(Keys.STATUS_ID, &""))
	var source_id := int(event_data.get(Keys.SOURCE_ID, 0))
	var target_id := int(event_data.get(Keys.TARGET_ID, 0))
	return make_target_key(status_id, source_id, target_id)


func get_token_key(event_data: Dictionary) -> String:
	var status_id := String(event_data.get(Keys.STATUS_ID, &""))
	var token_id := int(event_data.get(Keys.AFTER_TOKEN_ID, 0))
	if token_id <= 0:
		token_id = int(event_data.get(Keys.BEFORE_TOKEN_ID, 0))
	if status_id.is_empty() or token_id <= 0:
		return get_target_key_prefix(event_data)
	return make_token_key(status_id, token_id)


func build_markers(_event_data: Dictionary) -> Array[StatusDepictionMarkerCommand]:
	return []


func build_fx_commands(_event_data: Dictionary) -> Array[StatusDepictionFxCommand]:
	return []


static func make_source_key_prefix(status_id: StringName, source_id: int) -> String:
	return "%s:%d" % [String(status_id), int(source_id)]


static func make_target_key(status_id: StringName, source_id: int, target_id: int) -> String:
	return "%s:%d" % [make_source_key_prefix(status_id, source_id), int(target_id)]


static func make_token_key(status_id: StringName, token_id: int, source_id := 0) -> String:
	if int(source_id) > 0:
		return "%s:token:%d" % [make_source_key_prefix(status_id, source_id), int(token_id)]
	return "%s:token:%d" % [String(status_id), int(token_id)]


static func make_projection_key(status_id: StringName, target_id: int, token_id: int) -> String:
	return "%s:projection:%d:%d" % [String(status_id), int(target_id), int(token_id)]


static func marker(target_id: int, marker_kind: StringName) -> StatusDepictionMarkerCommand:
	var command := StatusDepictionMarkerCommand.new()
	command.target_id = int(target_id)
	command.kind = marker_kind
	return command


static func ensure_persistent_fx(
	target_id: int,
	key: String,
	fx_id: StringName,
	fade_in := 0.06,
	scale := 1.05,
	center_y_ratio := 0.5
) -> StatusDepictionFxCommand:
	var command := StatusDepictionFxCommand.new()
	command.op = FX_OP_ENSURE_PERSISTENT
	command.target_id = int(target_id)
	command.key = String(key)
	command.fx_id = fx_id
	command.fade_in = float(fade_in)
	command.scale = float(scale)
	command.center_y_ratio = float(center_y_ratio)
	return command


static func clear_persistent_fx(key: String, fade_out := 0.06) -> StatusDepictionFxCommand:
	var command := StatusDepictionFxCommand.new()
	command.op = FX_OP_CLEAR_PERSISTENT
	command.key = String(key)
	command.fade_out = float(fade_out)
	return command
