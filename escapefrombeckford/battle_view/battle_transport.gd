# battle_transport.gd
class_name BattleTransport extends RefCounted

var tempo_bpm: float = 120.0

func seconds_for_quarters(q: float) -> float:
	# q = number of quarter notes
	return maxf(0.0, (60.0 / tempo_bpm) * q)
