# event_sink_main.gd

class_name EventSinkMain extends EventSink

var be_log: BattleEventLog

func _init(_log: BattleEventLog) -> void:
	be_log = _log

func append(e: BattleEvent) -> int:
	if log == null:
		return -1
	return be_log.append(e)
