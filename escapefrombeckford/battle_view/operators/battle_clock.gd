# battle_clock.gd
class_name BattleClock
extends RefCounted

func start() -> void: pass
func stop() -> void: pass
func now_sec() -> float: return 0.0
func seconds_per_quarter() -> float: return 0.5

func wait_until(t_sec: float) -> Signal:
	return Signal()

func next_grid_time(now_sec: float, grid_quarters: float) -> float:
	# Default: quantize to quarter-notes
	var spq := seconds_per_quarter()
	if spq <= 0.0:
		return now_sec
	var grid_sec := maxf(0.0001, spq * maxf(grid_quarters, 0.25))
	var k := ceilf(now_sec / grid_sec)
	return k * grid_sec

func next_downbeat_time(now_sec: float, beats_per_bar: float = 4.0) -> float:
	return next_grid_time(now_sec, beats_per_bar)
