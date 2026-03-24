# event_sink_preview.gd

class_name EventSinkPreview extends EventSink

func append(_e: BattleEvent) -> int:
	# Preview sink intentionally discards events for now.
	return 0
