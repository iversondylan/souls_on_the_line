@tool
extends EditorScript

## RUN THIS AFTER YOU ADD / REMOVE / RENAME / EDIT ANY ARCANA OR STATUS .tres FILE.
## THIS SCRIPT UPDATES:
##   1. THE ARCANA COLLECTION
##   2. THE ARCANUM CATALOG
##   3. THE ARCANA REWARD POOL
##   4. THE STATUS CATALOG
##
## HOW TO RUN IT IN GODOT:
##   1. OPEN THIS FILE: res://tools/editor/upkeep_run_me.gd
##   2. IN THE SCRIPT EDITOR, USE: File -> Run
##   3. WATCH THE OUTPUT PANEL FOR SUCCESS OR FAILURE
##
## WHY THIS EXISTS:
##   YOU SHOULD NOT HAVE TO REMEMBER MULTIPLE LITTLE MAINTENANCE SCRIPTS.
##   THIS IS THE ONE OBNOXIOUS SCRIPT YOU ARE SUPPOSED TO REMEMBER.
##
## AFTER RUNNING:
##   IF THIS SCRIPT CHANGES .tres FILES, SAVE / REVIEW / COMMIT THOSE CHANGES.

const ContentUpkeepHelper = preload("res://tools/editor/content_upkeep_helper.gd")


func _run() -> void:
	var results := ContentUpkeepHelper.run_all()
	_print_step_result(results.get("arcana_catalog", {}), "arcanum catalog")
	_print_step_result(results.get("arcana_reward_pool", {}), "arcana reward pool")
	_print_step_result(results.get("status_catalog", {}), "status catalog")

	if bool(results.get("ok", false)):
		print("UPKEEP OK: all upkeep tasks completed successfully.")
	else:
		push_error("UPKEEP FAILED: at least one upkeep task failed. Read the errors above.")


func _print_step_result(result: Dictionary, fallback_label: String) -> void:
	var label := str(result.get("label", fallback_label))
	if bool(result.get("ok", false)):
		print("UPKEEP OK: rebuilt %s (%s items)." % [label, int(result.get("count", 0))])
		return
	push_error("UPKEEP FAILED: %s -> %s" % [label, str(result.get("error", "unknown error"))])
