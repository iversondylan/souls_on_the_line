# director_cue.gd

class_name DirectorCue extends RefCounted

var beat_q: float = 0.0			# absolute or turn-relative quarter-note position
var tempo_bpm: float = 120.0
var index: int = 0				# stable ordering within plan

var tags: Array[StringName] = []	# e.g. ["focus"], ["fire"], ["impact"], ["clear_focus"]

# semantic orders to start at this beat
var orders: Array[PresentationOrder] = []

# raw BattleEvents whose state changes should be applied at this beat
var events: Array[BattleEvent] = []

var label: String = ""
