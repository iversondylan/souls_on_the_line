# battle_transport_session.gd

class_name BattleTransportSession
extends BattleClock

enum MusicCycleState {
	IDLE,
	WAITING_TO_START,
	PLAYING,
	BETWEEN_LOOPS,
}

enum SyncMode {
	WALL_CLOCK,
	WEB_WAITING_FOR_AUDIO_LOCK,
	WEB_AUDIO_LOCKED,
	WEB_FALLBACK_WALL_CLOCK,
}

const WEB_AUDIO_LOCK_TIMEOUT_SEC := 0.75
const WEB_AUDIO_LOCK_EPSILON_SEC := 0.01
const WEB_LOOP_END_EPSILON_SEC := 0.02
const WEB_LOOP_WRAP_EPSILON_SEC := 0.05
const WEB_STOPPED_AT_END_EPSILON_SEC := 0.10

var tempo_bpm: float = 120.0
var offset_sec: float = 0.0
var music_stream: AudioStream = null
var music_volume_db: float = 0.0
var music_pitch_scale: float = 1.0
var metronome_sound: Sound = null

var _tree: SceneTree
var _started := false
var _paused := false
var _paused_now_sec: float = 0.0
var _transport_start_usec: int = 0
var _paused_started_usec: int = 0
var _paused_accum_usec: int = 0
var _wall_transport_offset_sec: float = 0.0
var _sync_mode: int = SyncMode.WALL_CLOCK
var _music_cycle_state: int = MusicCycleState.IDLE
var _next_music_start_transport_sec: float = 0.0
var _music_cycle_anchor_transport_sec: float = -1.0
var _music_cycle_duration_sec: float = 0.0
var _paused_music_playback_position_sec: float = 0.0
var _last_music_playback_position_sec: float = 0.0
var _requested_music_playback_position_sec: float = 0.0
var _audio_lock_hold_transport_sec: float = 0.0
var _audio_lock_wait_started_wall_sec: float = 0.0
var _web_fallback_for_session := false
var _loop_count: int = 0
var _warning_message: String = ""


func _init(
	tree: SceneTree,
	stream: AudioStream,
	bpm: float = 120.0,
	offset: float = 0.0,
	metronome: Sound = null,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	_tree = tree
	music_stream = stream
	tempo_bpm = bpm
	offset_sec = offset
	metronome_sound = metronome
	music_volume_db = volume_db
	music_pitch_scale = pitch_scale


func start() -> void:
	_started = true
	_paused = false
	_paused_now_sec = 0.0
	_transport_start_usec = Time.get_ticks_usec()
	_paused_started_usec = 0
	_paused_accum_usec = 0
	_wall_transport_offset_sec = 0.0
	_sync_mode = SyncMode.WALL_CLOCK
	_music_cycle_state = MusicCycleState.IDLE
	_next_music_start_transport_sec = maxf(offset_sec, 0.0)
	_music_cycle_anchor_transport_sec = -1.0
	_music_cycle_duration_sec = _get_stream_length_sec(music_stream, music_pitch_scale)
	_paused_music_playback_position_sec = 0.0
	_last_music_playback_position_sec = 0.0
	_requested_music_playback_position_sec = 0.0
	_audio_lock_hold_transport_sec = 0.0
	_audio_lock_wait_started_wall_sec = 0.0
	_loop_count = 0
	_warning_message = ""
	_web_fallback_for_session = false

	MusicPlayer.configure_metronome(metronome_sound)
	MusicPlayer.stop_music()
	MusicPlayer.stop_metronome()

	if music_stream != null:
		_music_cycle_state = MusicCycleState.WAITING_TO_START
		if _next_music_start_transport_sec <= 0.0:
			_start_music_cycle(0.0, _next_music_start_transport_sec, _is_web_transport())
	else:
		_music_cycle_state = MusicCycleState.IDLE


func stop() -> void:
	_started = false
	_paused = false
	_paused_now_sec = 0.0
	_transport_start_usec = 0
	_paused_started_usec = 0
	_paused_accum_usec = 0
	_wall_transport_offset_sec = 0.0
	_sync_mode = SyncMode.WALL_CLOCK
	_music_cycle_state = MusicCycleState.IDLE
	_next_music_start_transport_sec = 0.0
	_music_cycle_anchor_transport_sec = -1.0
	_music_cycle_duration_sec = 0.0
	_paused_music_playback_position_sec = 0.0
	_last_music_playback_position_sec = 0.0
	_requested_music_playback_position_sec = 0.0
	_audio_lock_hold_transport_sec = 0.0
	_audio_lock_wait_started_wall_sec = 0.0
	_web_fallback_for_session = false
	_loop_count = 0
	_warning_message = ""
	MusicPlayer.stop_metronome()
	MusicPlayer.stop_music()


func pause() -> void:
	if !_started or _paused:
		return
	_paused_now_sec = now_sec()
	_paused_started_usec = Time.get_ticks_usec()
	_paused_music_playback_position_sec = 0.0
	_paused = true
	if _music_cycle_state == MusicCycleState.PLAYING:
		_paused_music_playback_position_sec = MusicPlayer.get_music_position_precise()
		_last_music_playback_position_sec = _paused_music_playback_position_sec
		MusicPlayer.pause_metronome()
		MusicPlayer.pause_music()


func resume() -> void:
	if !_started or !_paused:
		return
	_paused_accum_usec += Time.get_ticks_usec() - _paused_started_usec
	_paused_started_usec = 0
	_paused = false
	if _music_cycle_state != MusicCycleState.PLAYING:
		return

	if _is_web_transport():
		MusicPlayer.stop_metronome()
		MusicPlayer.stop_music()
		var anchor_transport_sec: float = _paused_now_sec - _paused_music_playback_position_sec
		_start_music_cycle(_paused_music_playback_position_sec, anchor_transport_sec, true)
		return

	MusicPlayer.resume_music()
	MusicPlayer.resume_metronome()


func is_paused() -> bool:
	return _paused


func seconds_per_quarter() -> float:
	return 60.0 / maxf(tempo_bpm, 0.001)


func now_sec() -> float:
	if !_started:
		return 0.0
	if _paused:
		return _paused_now_sec
	if _transport_start_usec <= 0:
		return 0.0

	match _sync_mode:
		SyncMode.WEB_WAITING_FOR_AUDIO_LOCK:
			return _audio_lock_hold_transport_sec
		SyncMode.WEB_AUDIO_LOCKED:
			var audio_now: float = _get_audio_locked_now_sec()
			if audio_now >= 0.0:
				return audio_now
			return _audio_lock_hold_transport_sec
		_:
			return _wall_now_sec() + _wall_transport_offset_sec


func now_quarters() -> float:
	return now_sec() / seconds_per_quarter()


func update() -> void:
	if !_started or _paused or music_stream == null:
		return

	match _music_cycle_state:
		MusicCycleState.WAITING_TO_START, MusicCycleState.BETWEEN_LOOPS:
			if now_sec() >= _next_music_start_transport_sec:
				_start_music_cycle(0.0, _next_music_start_transport_sec, _is_web_transport())
		MusicCycleState.PLAYING:
			if _music_cycle_duration_sec <= 0.0:
				_finish_music_cycle(now_sec())
				return

			var track_end_transport_sec: float = _music_cycle_anchor_transport_sec + _music_cycle_duration_sec
			match _sync_mode:
				SyncMode.WEB_WAITING_FOR_AUDIO_LOCK:
					_update_web_waiting_for_audio_lock()
				SyncMode.WEB_AUDIO_LOCKED:
					_update_web_audio_locked_cycle(track_end_transport_sec)
				_:
					if now_sec() >= track_end_transport_sec:
						_finish_music_cycle(track_end_transport_sec)


func wait_until(t_sec: float) -> void:
	if _tree == null:
		return
	while _started and now_sec() < t_sec:
		await _tree.process_frame


func wait_seconds(delta_sec: float) -> void:
	await wait_until(now_sec() + maxf(delta_sec, 0.0))


func get_debug_snapshot() -> Dictionary:
	var playback_position_sec: float = MusicPlayer.get_music_position_precise()
	var audio_transport_sec: float = -1.0
	if _music_cycle_anchor_transport_sec >= 0.0:
		audio_transport_sec = _music_cycle_anchor_transport_sec + playback_position_sec

	return {
		"sync_mode": _sync_mode_name(_sync_mode),
		"music_cycle_state": _music_cycle_state_name(_music_cycle_state),
		"transport_now_sec": now_sec(),
		"wall_now_sec": _wall_now_sec(),
		"music_playback_position_sec": playback_position_sec,
		"cycle_anchor_transport_sec": _music_cycle_anchor_transport_sec,
		"cycle_duration_sec": _music_cycle_duration_sec,
		"next_cycle_start_transport_sec": _next_music_start_transport_sec,
		"paused_playback_position_sec": _paused_music_playback_position_sec,
		"requested_playback_position_sec": _requested_music_playback_position_sec,
		"audio_lock_hold_transport_sec": _audio_lock_hold_transport_sec,
		"loop_count": _loop_count,
		"warning": _warning_message,
		"drift_sec": _compute_debug_drift_sec(audio_transport_sec),
		"is_music_active": MusicPlayer.is_music_actively_playing(),
		"audio_transport_sec": audio_transport_sec,
		"lock_wait_elapsed_sec": maxf(0.0, _wall_now_sec() - _audio_lock_wait_started_wall_sec),
		"lock_timeout_sec": WEB_AUDIO_LOCK_TIMEOUT_SEC,
	}


func _start_music_cycle(
	from_position: float = 0.0,
	anchor_transport_sec: float = 0.0,
	use_explicit_anchor: bool = false
) -> void:
	if music_stream == null:
		_music_cycle_state = MusicCycleState.IDLE
		return

	var clamped_from_position: float = maxf(from_position, 0.0)
	_music_cycle_duration_sec = _get_stream_length_sec(music_stream, music_pitch_scale)
	if _music_cycle_duration_sec <= 0.0:
		MusicPlayer.stop_metronome()
		MusicPlayer.stop_music()
		_music_cycle_anchor_transport_sec = -1.0
		_music_cycle_state = MusicCycleState.IDLE
		return

	var resolved_anchor_transport_sec: float = anchor_transport_sec
	if !use_explicit_anchor:
		resolved_anchor_transport_sec = now_sec() - clamped_from_position

	_music_cycle_anchor_transport_sec = resolved_anchor_transport_sec
	_music_cycle_state = MusicCycleState.PLAYING
	_paused_music_playback_position_sec = 0.0
	_last_music_playback_position_sec = clamped_from_position
	_requested_music_playback_position_sec = clamped_from_position
	_audio_lock_hold_transport_sec = resolved_anchor_transport_sec + clamped_from_position

	if _should_use_web_audio_lock():
		_begin_web_waiting_cycle(clamped_from_position)
		return

	_begin_wall_clock_cycle(clamped_from_position)


func _begin_wall_clock_cycle(from_position: float) -> void:
	_sync_mode = SyncMode.WEB_FALLBACK_WALL_CLOCK if _is_web_transport() else SyncMode.WALL_CLOCK
	_wall_transport_offset_sec = (_music_cycle_anchor_transport_sec + from_position) - _wall_now_sec()
	_play_music_cycle(from_position)


func _begin_web_waiting_cycle(from_position: float) -> void:
	_sync_mode = SyncMode.WEB_WAITING_FOR_AUDIO_LOCK
	_audio_lock_wait_started_wall_sec = _wall_now_sec()
	_audio_lock_hold_transport_sec = _music_cycle_anchor_transport_sec + from_position
	_play_music_cycle(from_position)


func _play_music_cycle(from_position: float) -> void:
	MusicPlayer.play_music(music_stream, from_position, music_volume_db, music_pitch_scale)
	if metronome_sound != null:
		MusicPlayer.configure_metronome(metronome_sound)
		MusicPlayer.play_metronome(from_position)


func _finish_music_cycle(track_end_transport_sec: float) -> void:
	MusicPlayer.stop_metronome()
	MusicPlayer.stop_music()
	_music_cycle_anchor_transport_sec = -1.0
	_paused_music_playback_position_sec = 0.0
	_last_music_playback_position_sec = 0.0
	_requested_music_playback_position_sec = 0.0
	_audio_lock_hold_transport_sec = track_end_transport_sec
	_next_music_start_transport_sec = next_grid_time(track_end_transport_sec, 1.0) + maxf(offset_sec, 0.0)
	_music_cycle_state = MusicCycleState.BETWEEN_LOOPS
	_loop_count += 1
	if _sync_mode == SyncMode.WEB_AUDIO_LOCKED or _sync_mode == SyncMode.WEB_WAITING_FOR_AUDIO_LOCK:
		_sync_mode = SyncMode.WALL_CLOCK
	if _sync_mode == SyncMode.WEB_FALLBACK_WALL_CLOCK:
		_wall_transport_offset_sec = track_end_transport_sec - _wall_now_sec()


func _update_web_waiting_for_audio_lock() -> void:
	var playback_position_sec: float = MusicPlayer.get_music_position_precise()
	var has_lock: bool = (
		MusicPlayer.is_music_actively_playing()
		and playback_position_sec >= _requested_music_playback_position_sec + WEB_AUDIO_LOCK_EPSILON_SEC
	)
	if has_lock:
		_sync_mode = SyncMode.WEB_AUDIO_LOCKED
		_last_music_playback_position_sec = playback_position_sec
		if _warning_message.begins_with("Web audio lock lost"):
			_set_warning("")
		return

	if _wall_now_sec() - _audio_lock_wait_started_wall_sec >= WEB_AUDIO_LOCK_TIMEOUT_SEC:
		_enter_web_fallback("Web audio lock timed out; falling back to wall clock sync.")


func _update_web_audio_locked_cycle(track_end_transport_sec: float) -> void:
	var playback_position_sec: float = MusicPlayer.get_music_position_precise()
	var wrapped: bool = (
		_last_music_playback_position_sec > WEB_LOOP_WRAP_EPSILON_SEC
		and playback_position_sec + WEB_LOOP_WRAP_EPSILON_SEC < _last_music_playback_position_sec
	)
	var reached_end: bool = playback_position_sec >= _music_cycle_duration_sec - WEB_LOOP_END_EPSILON_SEC
	var stopped_at_end: bool = (
		!MusicPlayer.is_music_actively_playing()
		and _last_music_playback_position_sec >= _music_cycle_duration_sec - WEB_STOPPED_AT_END_EPSILON_SEC
	)

	if wrapped or reached_end or stopped_at_end:
		_finish_music_cycle(track_end_transport_sec)
		return

	if !MusicPlayer.is_music_actively_playing():
		_begin_web_relock_wait()
		return

	_last_music_playback_position_sec = maxf(playback_position_sec, _last_music_playback_position_sec)


func _begin_web_relock_wait() -> void:
	_sync_mode = SyncMode.WEB_WAITING_FOR_AUDIO_LOCK
	_requested_music_playback_position_sec = _last_music_playback_position_sec
	_audio_lock_hold_transport_sec = _music_cycle_anchor_transport_sec + _last_music_playback_position_sec
	_audio_lock_wait_started_wall_sec = _wall_now_sec()
	_set_warning("Web audio lock lost; waiting to relock.")


func _enter_web_fallback(message: String) -> void:
	_web_fallback_for_session = true
	_sync_mode = SyncMode.WEB_FALLBACK_WALL_CLOCK
	_wall_transport_offset_sec = _audio_lock_hold_transport_sec - _wall_now_sec()
	_set_warning(message)


func _get_stream_length_sec(stream: AudioStream, pitch_scale: float = 1.0) -> float:
	if stream == null:
		return 0.0
	return MusicPlayer.get_stream_length_sec(stream, pitch_scale)


func _wall_now_sec() -> float:
	return float(Time.get_ticks_usec() - _transport_start_usec - _paused_accum_usec) / 1000000.0


func _is_web_transport() -> bool:
	return OS.has_feature("web")


func _should_use_web_audio_lock() -> bool:
	return _is_web_transport() and !_web_fallback_for_session


func _get_audio_locked_now_sec() -> float:
	if _music_cycle_state != MusicCycleState.PLAYING or music_stream == null:
		return -1.0
	if !MusicPlayer.is_music_actively_playing():
		return -1.0
	return _music_cycle_anchor_transport_sec + MusicPlayer.get_music_position_precise()


func _compute_debug_drift_sec(audio_transport_sec: float) -> float:
	if audio_transport_sec < 0.0:
		return 0.0
	var wall_transport_sec: float = _wall_now_sec() + _wall_transport_offset_sec
	return wall_transport_sec - audio_transport_sec


func _set_warning(message: String) -> void:
	if _warning_message == message:
		return
	_warning_message = message
	if !_warning_message.is_empty():
		print("[BattleTransportSession] %s" % _warning_message)


func _music_cycle_state_name(value: int) -> String:
	if value >= 0 and value < MusicCycleState.keys().size():
		return MusicCycleState.keys()[value]
	return "UNKNOWN"


func _sync_mode_name(value: int) -> String:
	if value >= 0 and value < SyncMode.keys().size():
		return SyncMode.keys()[value]
	return "UNKNOWN"
