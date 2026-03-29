# metronome_clock.gd

#class_name MetronomeClock extends BattleClock
#
#var _player: AudioStreamPlayer
#var _bpm: float = 120.0
#var _offset_sec: float = 0.0
#var _tree: SceneTree
#
#var _running := false
#var _start_usec: int = 0
#
#func _init(player: AudioStreamPlayer, bpm: float, offset_sec: float, tree: SceneTree) -> void:
	#_player = player
	#_bpm = bpm
	#_offset_sec = offset_sec
	#_tree = tree
#
#func start() -> void:
	#_running = true
	#_start_usec = Time.get_ticks_usec()
	#if _player != null:
		#_player.play()
#
#func stop() -> void:
	#_running = false
	#if _player != null:
		#_player.stop()
#
#func seconds_per_quarter() -> float:
	#return 60.0 / _bpm
#
#func now_sec() -> float:
	#if !_running:
		#return _offset_sec
	#return _offset_sec + float(Time.get_ticks_usec() - _start_usec) / 1000000.0
#
#func wait_until(t_sec: float) -> Signal:
	#var dt := maxf(0.0, t_sec - now_sec())
	#return _tree.create_timer(maxf(dt, 0.0001)).timeout
