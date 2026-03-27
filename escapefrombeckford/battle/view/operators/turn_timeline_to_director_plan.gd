# turn_timeline_to_director_plan.gd

class_name TurnTimelineToDirectorPlan extends RefCounted

func build_plan(timeline: TurnTimeline, t_start_sec: float, tempo_bpm: float) -> DirectorPlan:
	var plan := DirectorPlan.new()
	plan.t_start_sec = t_start_sec
	plan.tempo_bpm = tempo_bpm
	plan.cues = []

	if timeline == null:
		return plan

	for i in range(timeline.beats.size()):
		var tb := timeline.beats[i]
		if tb == null:
			continue

		var cue := DirectorCue.new()
		cue.beat_q = tb.beat_q
		cue.tempo_bpm = tempo_bpm
		cue.index = i
		cue.label = tb.label
		cue.orders = tb.orders
		cue.events = tb.events
		plan.cues.append(cue)

	return plan
