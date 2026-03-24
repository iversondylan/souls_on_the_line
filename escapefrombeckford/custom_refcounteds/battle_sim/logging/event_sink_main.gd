# event_sink_main.gd

class_name EventSinkMain extends EventSink

var log: BattleEventLog

func _init(_log: BattleEventLog) -> void:
	log = _log

func append(e: BattleEvent) -> int:
	if log == null:
		return 0
	return log.append(e)
