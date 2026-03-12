# beat_package.gd
class_name BeatPackage extends RefCounted

var beat: Array[BattleEvent] = []
var gen: int = 0

# how long this beat “owns the timeline”
var wait_quarters: float = 0.0
var duration_sec: float = 0.0
