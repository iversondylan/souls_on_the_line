# metronome_clock.gd
class_name MetronomeClock extends BattleClock

var _player: AudioStreamPlayer
var _bpm: float = 120.0
var _offset_sec: float = 0.0

# internal: a reusable Timer node owner (SceneTree)
var _tree: SceneTree

func _init(player: AudioStreamPlayer, bpm: float, offset_sec: float, tree: SceneTree) -> void:
	_player = player
	_bpm = bpm
	_offset_sec = offset_sec
	_tree = tree

func start() -> void:
	_player.play()

func stop() -> void:
	pass

func seconds_per_quarter() -> float:
	return 60.0 / _bpm

func now_sec() -> float:
	if _player == null:
		return 0.0
	# playback position is 0 at play() start; add offset for “music time”
	return float(_player.get_playback_position()) + _offset_sec

func wait_until(t_sec: float) -> Signal:
	# IMPORTANT: This returns a signal to await.
	# Implementation uses create_timer once; no process_frame loops required.
	var dt := maxf(0.0, t_sec - now_sec())
	# guard: if already past target, return a timer that fires immediately next tick
	return _tree.create_timer(maxf(dt, 0.0001)).timeout
