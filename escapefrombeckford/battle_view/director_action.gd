# director_action.gd

class_name DirectorAction extends RefCounted

var t_rel: float = 0.0 # seconds from plan start
var event: BattleEvent = null
var duration: float = 0.0

var label: String = ""
