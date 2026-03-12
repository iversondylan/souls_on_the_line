# music_sync_player.gd
extends Node

@onready var metronome_player: AudioStreamPlayer = $MetronomePlayer

@export var bus := "Music"
@export var metronome_sound: Sound # drag your 120bpm Sound resource here

var clock: BattleClock

func _ready() -> void:
	# ... your existing setup ...
	var p := MusicPlayer.metronome_player
	p.stream = metronome_sound.stream
	p.bus = "Music"
	p.volume_db = metronome_sound.volume_db
	p.pitch_scale = metronome_sound.pitch

	clock = MetronomeClock.new(p, 120.0, 0.0) # offset_sec tweak later

func play(sound, single := false, runtime_volume_db := 0.0, runtime_pitch := 0.0) -> void:
	if not sound:
		return
	
	if single:
		stop()
	
	for player in get_children():
		player = player as AudioStreamPlayer
		if player.playing:
			continue
	
		#player.bus = bus
	
		if sound is Sound:
			var profile := sound as Sound
			player.stream = profile.stream
			var volume_random_mod := 0.0
			var pitch_random_mod := 0.0
			if profile.volume_random != 0.0:
				volume_random_mod = randf_range(-profile.volume_random, profile.volume_random)
			if profile.pitch_random != 0.0:
				pitch_random_mod = randf_range(-profile.pitch_random, profile.pitch_random)
			player.volume_db = profile.volume_db + runtime_volume_db + volume_random_mod
			player.pitch_scale = profile.pitch + runtime_pitch + pitch_random_mod
		elif sound is AudioStream:
			# Backward compatibility
			player.stream = sound
			player.volume_db = runtime_volume_db
			player.pitch_scale = 1.0 + runtime_pitch
		else:
			push_warning("sound_player.gd provided sound is not an AudioStream or a SoundProfile")
	
		player.play()
		break

func stop() -> void:
	for player in get_children():
		player = player as AudioStreamPlayer
		player.stop()
