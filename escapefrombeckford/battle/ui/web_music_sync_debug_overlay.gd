class_name WebMusicSyncDebugOverlay
extends PanelContainer

@onready var text_label: Label = $MarginContainer/Label

var transport_session: BattleTransportSession = null
var _manual_visible := false
var _debug_visible := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_visibility()
	_update_text()


func bind_transport_session(session: BattleTransportSession) -> void:
	transport_session = session
	_update_text()


func set_manual_visible(value: bool) -> void:
	_manual_visible = value
	_refresh_visibility()


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	_refresh_visibility()


func _process(_delta: float) -> void:
	if !visible:
		return
	_update_text()


func _refresh_visibility() -> void:
	visible = _manual_visible or _debug_visible


func _update_text() -> void:
	if text_label == null:
		return
	if transport_session == null:
		text_label.text = "Music Sync Debug\nNo transport session bound."
		return

	var snapshot: Dictionary = transport_session.get_debug_snapshot()
	var warning: String = String(snapshot.get("warning", ""))
	if warning.is_empty():
		warning = "-"

	text_label.text = "\n".join([
		"Music Sync Debug (F9)",
		"sync=%s cycle=%s" % [
			String(snapshot.get("sync_mode", "UNKNOWN")),
			String(snapshot.get("music_cycle_state", "UNKNOWN")),
		],
		"transport=%.3f wall=%.3f drift=%.3f" % [
			float(snapshot.get("transport_now_sec", 0.0)),
			float(snapshot.get("wall_now_sec", 0.0)),
			float(snapshot.get("drift_sec", 0.0)),
		],
		"playback=%.3f active=%s" % [
			float(snapshot.get("music_playback_position_sec", 0.0)),
			str(bool(snapshot.get("is_music_active", false))),
		],
		"anchor=%.3f next=%.3f dur=%.3f" % [
			float(snapshot.get("cycle_anchor_transport_sec", -1.0)),
			float(snapshot.get("next_cycle_start_transport_sec", 0.0)),
			float(snapshot.get("cycle_duration_sec", 0.0)),
		],
		"paused=%.3f requested=%.3f hold=%.3f" % [
			float(snapshot.get("paused_playback_position_sec", 0.0)),
			float(snapshot.get("requested_playback_position_sec", 0.0)),
			float(snapshot.get("audio_lock_hold_transport_sec", 0.0)),
		],
		"lock=%.3f/%.3f loops=%d" % [
			float(snapshot.get("lock_wait_elapsed_sec", 0.0)),
			float(snapshot.get("lock_timeout_sec", 0.0)),
			int(snapshot.get("loop_count", 0)),
		],
		"warning=%s" % warning,
	])
