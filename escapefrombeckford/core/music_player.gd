# music_player.gd
extends Node

@export var bus := &"Music"

const BACKWARDS_JITTER_TOLERANCE_SEC := 0.02

@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer2
@onready var metronome_player: AudioStreamPlayer = $MetronomePlayer

var _last_music_compensated_position_sec: float = 0.0
var _last_metronome_compensated_position_sec: float = 0.0


func _ready() -> void:
	music_player.bus = bus
	metronome_player.bus = bus


func play_music(
	stream: AudioStream,
	from_position: float = 0.0,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0
) -> void:
	if stream == null:
		return
	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.pitch_scale = pitch_scale
	music_player.stream_paused = false
	music_player.play(maxf(from_position, 0.0))


func pause_music() -> void:
	if music_player.stream == null:
		return
	music_player.stream_paused = true


func resume_music() -> void:
	if music_player.stream == null:
		return
	music_player.stream_paused = false


func stop_music() -> void:
	music_player.stream_paused = false
	music_player.stop()
	_last_music_compensated_position_sec = 0.0


func get_music_position_precise() -> float:
	return get_music_position_compensated()


func get_music_position_compensated(allow_backwards_reset: bool = false) -> float:
	_last_music_compensated_position_sec = _get_compensated_position(
		music_player,
		_last_music_compensated_position_sec,
		allow_backwards_reset
	)
	return _last_music_compensated_position_sec


func is_music_actively_playing() -> bool:
	return music_player != null and music_player.playing and !music_player.stream_paused


func configure_metronome(sound: Sound) -> void:
	if sound == null or sound.stream == null:
		stop_metronome()
		metronome_player.stream = null
		return
	metronome_player.stream = sound.stream
	metronome_player.volume_db = sound.volume_db
	metronome_player.pitch_scale = sound.pitch


func play_metronome(from_position: float = 0.0) -> void:
	if metronome_player.stream == null:
		return
	metronome_player.stream_paused = false
	metronome_player.play(maxf(from_position, 0.0))


func pause_metronome() -> void:
	if metronome_player.stream == null:
		return
	metronome_player.stream_paused = true


func resume_metronome() -> void:
	if metronome_player.stream == null:
		return
	metronome_player.stream_paused = false


func stop_metronome() -> void:
	metronome_player.stream_paused = false
	metronome_player.stop()
	_last_metronome_compensated_position_sec = 0.0


func get_metronome_position_precise() -> float:
	_last_metronome_compensated_position_sec = _get_compensated_position(
		metronome_player,
		_last_metronome_compensated_position_sec,
		false
	)
	return _last_metronome_compensated_position_sec


func get_stream_length_sec(stream: AudioStream, pitch_scale: float = 1.0) -> float:
	if stream == null:
		return 0.0
	return maxf(stream.get_length(), 0.0) / maxf(pitch_scale, 0.001)


func _get_raw_position(player: AudioStreamPlayer) -> float:
	if player == null or player.stream == null:
		return 0.0
	return maxf(0.0, player.get_playback_position())


func _get_precise_position(player: AudioStreamPlayer) -> float:
	if player == null or player.stream == null:
		return 0.0
	return _get_compensated_position(player, 0.0, true)


func _get_compensated_position(
	player: AudioStreamPlayer,
	last_position_sec: float,
	allow_backwards_reset: bool
) -> float:
	if player == null or player.stream == null:
		return 0.0

	var position := player.get_playback_position()
	if player.playing and !player.stream_paused:
		position += AudioServer.get_time_since_last_mix()
		position -= AudioServer.get_output_latency()
	position = maxf(0.0, position)

	if allow_backwards_reset:
		return position
	if position + BACKWARDS_JITTER_TOLERANCE_SEC < last_position_sec:
		return last_position_sec
	return maxf(0.0, position)
