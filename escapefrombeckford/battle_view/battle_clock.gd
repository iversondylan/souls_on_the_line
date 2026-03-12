# battle_clock.gd

class_name BattleClock extends RefCounted

func start() -> void:
	pass

func stop() -> void:
	pass

func now_sec() -> float:
	return 0.0

func wait_until(t_sec: float) -> Signal:
	# Returns a Signal you can await (from a Timer)
	return Signal()

func beat_sec() -> float:
	return 0.5 # default 120bpm
