@tool
extends EditorScript

## Legacy wrapper. Use res://tools/editor/upkeep_run_me.gd instead.
const ContentUpkeepHelper = preload("res://tools/editor/content_upkeep_helper.gd")

func _run() -> void:
	var result := ContentUpkeepHelper.rebuild_arcana_catalogs()
	if !bool(result.get("ok", false)):
		push_error("Legacy arcana catalog rebuild failed.")
