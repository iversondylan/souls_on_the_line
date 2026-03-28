# music_player.gd
extends Node

@export var bus := &"Music"

@onready var music_player: AudioStreamPlayer = $AudioStreamPlayer2
@onready var metronome_player: AudioStreamPlayer = $MetronomePlayer


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


func get_music_position_precise() -> float:
	return _get_precise_position(music_player)


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


func get_metronome_position_precise() -> float:
	return _get_precise_position(metronome_player)


func get_stream_length_sec(stream: AudioStream, pitch_scale: float = 1.0) -> float:
	if stream == null:
		return 0.0
	return maxf(stream.get_length(), 0.0) / maxf(pitch_scale, 0.001)


func _get_precise_position(player: AudioStreamPlayer) -> float:
	if player == null or player.stream == null:
		return 0.0
	var position := player.get_playback_position()
	if player.playing and !player.stream_paused:
		position += AudioServer.get_time_since_last_mix()
	return maxf(0.0, position)
