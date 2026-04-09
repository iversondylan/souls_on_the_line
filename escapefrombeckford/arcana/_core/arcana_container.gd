# arcana_container.gd
class_name ArcanaContainer extends HBoxContainer

const ARCANUM_DISPLAY := preload("uid://k1sxcd5o2me7")

@onready var arcana_control: ArcanaControl = $ArcanaControl
@onready var arcana_row: HBoxContainer = %ArcanaContainer

var system: ArcanaSystem = ArcanaSystem.new()

func _ready() -> void:
	arcana_row.child_exiting_tree.connect(_on_arcanum_display_exiting_tree)
	Events.arcanum_view_activated.connect(_on_arcanum_view_activated)
	#Events.live_battle_api_created.connect(_on_live_battle_api_created)


func _exit_tree() -> void:
	if Events.arcanum_view_activated.is_connected(_on_arcanum_view_activated):
		Events.arcanum_view_activated.disconnect(_on_arcanum_view_activated)

#func _on_live_battle_api_created(new_api: LiveBattleAPI) -> void:
	#if new_api:
		#system.set_api(new_api)

# --- Convenience wrappers (so call sites barely change) ---

func get_modifier_tokens_for(target: Node) -> Array[ModifierToken]:
	return system.get_modifier_tokens_for(target)

func add_arcana(arcana: Array[Arcanum]) -> void:
	for a in arcana:
		add_arcanum(a)

func add_arcanum(arcanum: Arcanum) -> void:
	if !arcanum:
		return
	if system.has_arcanum(arcanum.get_id()):
		return

	system.add_arcanum(arcanum)

	var d := ARCANUM_DISPLAY.instantiate() as ArcanumDisplay
	arcana_row.add_child(d)

	d.arcanum = arcanum
	arcanum.initialize_arcanum(d)

	system.bind_display(arcanum.get_id(), d)

func remove_arcanum(id: StringName) -> void:
	# Kill display first (triggers exiting-tree cleanup), then remove from system.
	for child in arcana_row.get_children():
		var d := child as ArcanumDisplay
		if d and d.arcanum and d.arcanum.get_id() == id:
			d.queue_free()
			break
	system.remove_arcanum(id)

func has_arcanum(id: StringName) -> bool:
	return system.has_arcanum(id)

func get_all_arcana() -> Array[Arcanum]:
	return system.get_all_arcana()

func _on_arcanum_display_exiting_tree(node: Node) -> void:
	var d := node as ArcanumDisplay
	if !d:
		return
	if d.arcanum:
		d.arcanum.deactivate_arcanum(d)
		system.unbind_display(d.arcanum.get_id())


func _on_arcanum_view_activated(arcanum_id: StringName, proc: int, source_id: int) -> void:
	system.play_view_activation(arcanum_id, proc, source_id)
