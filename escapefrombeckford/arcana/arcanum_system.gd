class_name ArcanaSystem extends HBoxContainer

#signal arcana_activated(type: Arcanum.Type)

const ARCANUM_APPLY_INTERVAL := 0.5
const ARCANUM_DISPLAY = preload("res://arcana/arcanum_display.tscn")

@onready var arcana_control: ArcanaControl = $ArcanaControl
@onready var arcana_container: HBoxContainer = %ArcanaContainer

func _ready() -> void:
	arcana_container.child_exiting_tree.connect(_on_arcanum_display_exiting_tree)
	
	add_arcanum(preload("res://arcana/general/unruly_pyric_wraps.tres"))
	#await get_tree().create_timer(1.0).timeout
	add_arcanum(preload("res://arcana/general/sigil_of_mana.tres"))
	#await get_tree().create_timer(1.0).timeout
	add_arcanum(preload("res://arcana/general/thales_flask.tres"))
	#await get_tree().create_timer(1.0).timeout
	add_arcanum(preload("res://arcana/general/vennards_vauxite.tres"))

func activate_arcana_by_type(type: Arcanum.Type) -> void:
	if type == Arcanum.Type.EVENT_BASED:
		return
	
	var arcanum_queue: Array[ArcanumDisplay] = _get_all_arcanum_display_nodes().filter(
		func(arcanum_display: ArcanumDisplay):
			return arcanum_display.arcanum.type == type
	)
	
	if arcanum_queue.is_empty():
		Events.arcana_activated.emit(type)
		return
	
	var tween := create_tween()
	for arcanum_display: ArcanumDisplay in arcanum_queue:
		tween.tween_callback(arcanum_display.arcanum.activate_arcanum.bind(arcanum_display))
		tween.tween_interval(ARCANUM_APPLY_INTERVAL)
	
	tween.finished.connect(func(): Events.arcana_activated.emit(type))

func add_arcana(arcana: Array[Arcanum]) -> void:
	for arcanum: Arcanum in arcana:
		add_arcanum(arcanum)

func add_arcanum(arcanum: Arcanum) -> void:
	if has_arcanum(arcanum.id):
		return
	
	var new_arcanum_display := ARCANUM_DISPLAY.instantiate() as ArcanumDisplay
	arcana_container.add_child(new_arcanum_display)
	new_arcanum_display.arcanum = arcanum
	new_arcanum_display.arcanum.initialize_arcanum(new_arcanum_display)

func has_arcanum(id: String) -> bool:
	for arcanum_display: ArcanumDisplay in arcana_container.get_children():
		if arcanum_display.arcanum.id == id and is_instance_valid(arcanum_display):
			return true
	return false

func get_all_arcana() -> Array[Arcanum]:
	var arcanum_displays := _get_all_arcanum_display_nodes()
	var arcana: Array[Arcanum] = []
	for arcanum_display: ArcanumDisplay in arcanum_displays:
		arcana.push_back(arcanum_display.arcanum)
	
	return arcana

func _get_all_arcanum_display_nodes() -> Array[ArcanumDisplay]:
	var all_arcana: Array[ArcanumDisplay] = []
	for arcanum_display: ArcanumDisplay in arcana_container.get_children():
		all_arcana.push_back(arcanum_display)
	return all_arcana

func _on_arcanum_display_exiting_tree(arcanum_display: ArcanumDisplay) -> void:
	if !arcanum_display:
		return
	if arcanum_display.arcanum:
		arcanum_display.arcanum.deactivate_arcanum(arcanum_display)
