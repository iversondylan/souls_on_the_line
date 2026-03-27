# turn_beat.gd

class_name TurnBeat extends RefCounted

var beat_q: float = 0.0
var orders: Array[PresentationOrder] = []
var events: Array[BattleEvent] = []
var label: String = ""
