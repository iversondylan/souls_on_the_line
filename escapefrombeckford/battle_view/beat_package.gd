# beat_package.gd

class_name BeatPackage extends RefCounted

var beat : Array[BattleEvent] = []
var gen: int = 0
var duration: float = 0.25
