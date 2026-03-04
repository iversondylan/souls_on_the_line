# battle_transport.gd
class_name BattleTransport extends RefCounted

var tempo: float = 130.0

# Later I add:
# func wait_beats(beats: float) -> void
# and in there I quantize against BPM + audio playback position

func get_beat_duration(note_denom: float) -> float:
	if note_denom >= 1.0 and note_denom <= 128.0:
		var duration: float = 240.0/(tempo * note_denom)
		return duration
	return 0
