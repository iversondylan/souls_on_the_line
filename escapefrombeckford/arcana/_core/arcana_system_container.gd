# arcana_system_container.gd
class_name ArcanaSystemContainer extends HBoxContainer

const ARCANUM_DISPLAY := preload("uid://k1sxcd5o2me7")

@onready var arcana_control: ArcanaControl = $ArcanaControl
@onready var arcana_row: HBoxContainer = %ArcanaContainer

var system: ArcanaSystem = ArcanaSystem.new()

func _ready() -> void:
	arcana_row.child_exiting_tree.connect(_on_arcanum_display_exiting_tree)
	Events.arcanum_view_activated.connect(_on_arcanum_view_activated)


func _exit_tree() -> void:
	if Events.arcanum_view_activated.is_connected(_on_arcanum_view_activated):
		Events.arcanum_view_activated.disconnect(_on_arcanum_view_activated)


func get_modifier_tokens_for(target: Node) -> Array[ModifierToken]:
	return system.get_modifier_tokens_for(target)


func activate_arcana_by_type(type: Arcanum.Type) -> void:
	system.activate_arcana_by_type(type, self)


func add_arcana(arcana: Array[Arcanum]) -> void:
	for a in arcana:
		add_arcanum(a)


func add_arcanum(arcanum: Arcanum) -> void:
	if !arcanum:
		return
	if system.has_arcanum(arcanum.get_id()):
		return

	system.add_arcanum(arcanum)

	var display := ARCANUM_DISPLAY.instantiate() as ArcanumDisplay
	arcana_row.add_child(display)

	display.arcanum = arcanum
	arcanum.initialize_arcanum(display)

	system.bind_display(arcanum.get_id(), display)


func remove_arcanum(id: StringName) -> void:
	for child in arcana_row.get_children():
		var display := child as ArcanumDisplay
		if display and display.arcanum and display.arcanum.get_id() == id:
			display.queue_free()
			break
	system.remove_arcanum(id)


func has_arcanum(id: StringName) -> bool:
	return system.has_arcanum(id)


func get_all_arcana() -> Array[Arcanum]:
	return system.get_all_arcana()


func _on_arcanum_display_exiting_tree(node: Node) -> void:
	var display := node as ArcanumDisplay
	if !display:
		return
	if display.arcanum:
		display.arcanum.deactivate_arcanum(display)
		system.unbind_display(display.arcanum.get_id())


func _on_arcanum_view_activated(arcanum_id: StringName, proc: int, source_id: int) -> void:
	system.play_view_activation(arcanum_id, proc, source_id)
