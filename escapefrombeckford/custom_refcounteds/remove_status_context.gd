# remove_status_context.gd
#class_name RemoveStatusContext
#extends RefCounted
#
#var source: Fighter = null
#var source_id: int = 0
#
#var target: Fighter = null
#var target_id: int = 0
#
#var status_id: StringName
#
## optional behavior flags
#var remove_all_intensity: bool = false
#
## results
#var removed: bool = false
#var removed_count: int = 0
#
#func hydrate_ids() -> void:
	#if source and source_id == 0:
		#source_id = source.combat_id
	#if target and target_id == 0:
		#target_id = target.combat_id
