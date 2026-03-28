# battle_transport_session.gd

class_name BattleTransportSession
extends BattleClock

enum MusicCycleState {
	IDLE,
	WAITING_TO_START,
	PLAYING,
	BETWEEN_LOOPS,
}

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
var _music_cycle_state: int = MusicCycleState.IDLE
var _next_music_start_transport_sec: float = 0.0
var _music_started_at_transport_sec: float = -1.0
var _music_cycle_duration_sec: float = 0.0
var _paused_music_playback_position_sec: float = 0.0


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
	_paused_music_playback_position_sec = 0.0
	_music_started_at_transport_sec = -1.0
	_music_cycle_duration_sec = _get_stream_cycle_duration_sec(music_stream, music_pitch_scale)
	_next_music_start_transport_sec = maxf(offset_sec, 0.0)
	MusicPlayer.configure_metronome(metronome_sound)
	MusicPlayer.stop_music()
	MusicPlayer.stop_metronome()

	if music_stream != null:
		_music_cycle_state = MusicCycleState.WAITING_TO_START
		if _next_music_start_transport_sec <= 0.0:
			_start_music_cycle()
	else:
		_music_cycle_state = MusicCycleState.IDLE


func stop() -> void:
	_started = false
	_paused = false
	_paused_now_sec = 0.0
	_transport_start_usec = 0
	_paused_started_usec = 0
	_paused_accum_usec = 0
	_paused_music_playback_position_sec = 0.0
	_music_started_at_transport_sec = -1.0
	_music_cycle_duration_sec = 0.0
	_next_music_start_transport_sec = 0.0
	_music_cycle_state = MusicCycleState.IDLE
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
		MusicPlayer.pause_metronome()
		MusicPlayer.pause_music()


func resume() -> void:
	if !_started or !_paused:
		return
	_paused_accum_usec += Time.get_ticks_usec() - _paused_started_usec
	_paused_started_usec = 0
	_paused = false
	if _music_cycle_state == MusicCycleState.PLAYING:
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
	return float(Time.get_ticks_usec() - _transport_start_usec - _paused_accum_usec) / 1000000.0


func now_quarters() -> float:
	return now_sec() / seconds_per_quarter()


func update() -> void:
	if !_started or _paused or music_stream == null:
		return

	var now := now_sec()
	match _music_cycle_state:
		MusicCycleState.WAITING_TO_START, MusicCycleState.BETWEEN_LOOPS:
			if now >= _next_music_start_transport_sec:
				_start_music_cycle()
		MusicCycleState.PLAYING:
			var track_end_transport_sec := _music_started_at_transport_sec + _music_cycle_duration_sec
			if _music_cycle_duration_sec <= 0.0:
				_finish_music_cycle(now)
			elif now >= track_end_transport_sec:
				_finish_music_cycle(track_end_transport_sec)


func wait_until(t_sec: float) -> void:
	if _tree == null:
		return
	while _started and now_sec() < t_sec:
		await _tree.process_frame


func wait_seconds(delta_sec: float) -> void:
	await wait_until(now_sec() + maxf(delta_sec, 0.0))


func _start_music_cycle(from_position: float = 0.0) -> void:
	if music_stream == null:
		_music_cycle_state = MusicCycleState.IDLE
		return

	var clamped_from_position := maxf(from_position, 0.0)
	var now := now_sec()
	_music_cycle_duration_sec = _get_stream_cycle_duration_sec(music_stream, music_pitch_scale)
	if _music_cycle_duration_sec <= 0.0:
		MusicPlayer.stop_metronome()
		MusicPlayer.stop_music()
		_music_started_at_transport_sec = -1.0
		_music_cycle_state = MusicCycleState.IDLE
		return
	_music_started_at_transport_sec = now - clamped_from_position
	_music_cycle_state = MusicCycleState.PLAYING
	_paused_music_playback_position_sec = 0.0

	MusicPlayer.play_music(music_stream, clamped_from_position, music_volume_db, music_pitch_scale)
	if metronome_sound != null:
		MusicPlayer.configure_metronome(metronome_sound)
		MusicPlayer.play_metronome(clamped_from_position)


func _finish_music_cycle(track_end_transport_sec: float) -> void:
	MusicPlayer.stop_metronome()
	MusicPlayer.stop_music()
	_music_started_at_transport_sec = -1.0
	_paused_music_playback_position_sec = 0.0
	_next_music_start_transport_sec = next_grid_time(track_end_transport_sec, 1.0) + maxf(offset_sec, 0.0)
	_music_cycle_state = MusicCycleState.BETWEEN_LOOPS


func _get_stream_cycle_duration_sec(stream: AudioStream, pitch_scale: float) -> float:
	if stream == null:
		return 0.0
	return MusicPlayer.get_stream_length_sec(stream, pitch_scale)
