# status_grid.gd

class_name StatusGrid extends GridContainer

#signal statuses_applied(proc_type: Status.ProcType)
#signal modifier_tokens_changed(type: Modifier.Type)
#signal intent_conditions_changed()
#
#const STATUS_APPLY_INTERVAL := 0.25
#const STATUS_DISPLAY_SCN = preload("res://scenes/status_handler/status_display.tscn")
#
#var status_system: StatusSystem = null
#var _displays_by_id: Dictionary = {} # StringName -> StatusDisplay
#
#
#var status_parent: Fighter
#var battle_scene: BattleScene
#
#func _ready() -> void:
	#_update_visuals()
#
#func bind_system(sys: StatusSystem, parent: Fighter) -> void:
	#status_system = sys
	#status_parent = parent
#
	#if status_system:
		#if !status_system.status_added.is_connected(_on_status_added):
			#status_system.status_added.connect(_on_status_added)
		#if !status_system.status_removed.is_connected(_on_status_removed):
			#status_system.status_removed.connect(_on_status_removed)
		#if !status_system.status_changed.is_connected(_on_status_changed_id):
			#status_system.status_changed.connect(_on_status_changed_id)
#
	## initial build
	#_rebuild_all()
#
#func _rebuild_all() -> void:
	## Clear old
	#for child in get_children():
		#child.queue_free()
	#_displays_by_id.clear()
	#await get_tree().process_frame
#
	#if !status_system:
		#_update_visuals()
		#return
#
	#for s in status_system.get_all():
		#_add_or_update_display(s)
#
	#_update_visuals()
#
#func _add_or_update_display(status: Status) -> void:
	#if !status:
		#return
	#var id := StringName(status.get_id())
	#if id == &"":
		#return
#
	#if _displays_by_id.has(id):
		#return
#
	#var d := STATUS_DISPLAY_SCN.instantiate() as StatusDisplay
	#add_child(d)
	#d.status_parent = status_parent
	#d.status = status
	#_displays_by_id[id] = d
#
#func _on_status_added(id: StringName) -> void:
	#if !status_system:
		#return
	#_add_or_update_display(status_system.get_status(id))
	#_update_visuals()
#
#func _on_status_removed(id: StringName) -> void:
	#if !_displays_by_id.has(id):
		#return
	#var d: StatusDisplay = _displays_by_id[id]
	#_displays_by_id.erase(id)
	#if d and is_instance_valid(d):
		#d.queue_free()
	#_update_visuals()
#
#func _on_status_changed_id(id: StringName) -> void:
	## StatusDisplay already listens to status.status_changed and updates its numbers,
	## so you might not need anything here, but you *may* want visuals update.
	#_update_visuals()
#
#func _update_visuals() -> void:
	#reset_size()
	#position.x = -0.5 * size.x
#
#func _on_gui_input(event: InputEvent) -> void:
	## do something
	##pass
	#if event.is_action_pressed("mouse_click"):
		#Events.status_tooltip_requested.emit(status_system.get_all())
