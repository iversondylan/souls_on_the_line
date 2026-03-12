# schedule_plan.gd

class_name SchedulePlan extends RefCounted

var t_start: float = 0.0
var t_end: float = 0.0
var actions: Array[DirectorAction] = []
