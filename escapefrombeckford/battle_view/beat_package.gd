# beat_package.gd

class_name BeatPackage extends RefCounted

var beat: Array[BattleEvent] = []
var gen: int = 0

# scheduling
var t_start_sec: float = 0.0
var t_next_sec: float = 0.0

# convenience (what the director cares about)
var wait_quarters: float = 0.0
var duration_sec: float = 0.0 # == t_next_sec - t_start_sec
