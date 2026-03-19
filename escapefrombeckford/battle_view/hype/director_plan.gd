# director_plan.gd

class_name DirectorPlan extends RefCounted


var t_start_sec: float = 0.0
var tempo_bpm: float = 120.0
var cues: Array[DirectorCue] = []
var handoff_gap_q: float = 1.0

func get_last_beat_q() -> float:
	var out := 0.0
	for cue in cues:
		if cue != null:
			out = maxf(out, cue.beat_q)
	return out

func get_end_sec() -> float:
	var spq := 60.0 / maxf(tempo_bpm, 1.0)
	return t_start_sec + (get_last_beat_q() + handoff_gap_q) * spq
