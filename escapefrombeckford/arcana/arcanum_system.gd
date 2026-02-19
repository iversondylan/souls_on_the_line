# arcanum_system.gd
class_name ArcanaSystem extends RefCounted

signal modifier_tokens_changed(mod_type: Modifier.Type)

const ARCANUM_APPLY_INTERVAL := 0.5

var api: LiveBattleAPI = null

# Ordered list (for display ordering)
var _arcana: Array[Arcanum] = []

# id -> Arcanum
var _by_id: Dictionary = {}

# id -> WeakRef(ArcanumDisplay)
var _display_by_id: Dictionary = {}

func set_api(new_api: LiveBattleAPI) -> void:
	api = new_api

func bind_display(arcanum_id: String, display: Node) -> void:
	if arcanum_id == "" or display == null:
		return
	_display_by_id[arcanum_id] = weakref(display)

func unbind_display(arcanum_id: String) -> void:
	_display_by_id.erase(arcanum_id)

func _get_display(arcanum_id: String) -> ArcanumDisplay:
	var wr : WeakRef = _display_by_id.get(arcanum_id, null)
	if wr == null:
		return null
	var d : ArcanumDisplay = wr.get_ref()
	if d == null or !is_instance_valid(d):
		return null
	return d as ArcanumDisplay

func has_arcanum(id: String) -> bool:
	return _by_id.has(id)

func get_all_arcana() -> Array[Arcanum]:
	return _arcana.duplicate()

func add_arcana(arcana: Array[Arcanum]) -> void:
	for a in arcana:
		add_arcanum(a)

func add_arcanum(arcanum: Arcanum) -> void:
	if !arcanum:
		return
	if arcanum.id == "":
		return
	if has_arcanum(arcanum.id):
		return

	_arcana.push_back(arcanum)
	_by_id[arcanum.id] = arcanum

	if arcanum.contributes_modifier():
		for mod_type in arcanum.get_contributed_modifier_types():
			modifier_tokens_changed.emit(mod_type)

func remove_arcanum(id: String) -> void:
	if id == "" or !_by_id.has(id):
		return

	var arcanum: Arcanum = _by_id[id]
	_by_id.erase(id)
	_arcana = _arcana.filter(func(a: Arcanum) -> bool: return a != arcanum)

	# Let event-based arcana detach from the Events bus.
	# We still pass the display if available (optional; can be null).
	var d := _get_display(id)
	arcanum.deactivate_arcanum(d)
	unbind_display(id)

	if arcanum.contributes_modifier():
		for mod_type in arcanum.get_contributed_modifier_types():
			modifier_tokens_changed.emit(mod_type)

func get_modifier_tokens_for(target: Node) -> Array[ModifierToken]:
	var tokens: Array[ModifierToken] = []
	for a in _arcana:
		if !a:
			continue
		if a.contributes_modifier():
			tokens.append_array(a.get_modifier_tokens_for(target))
	return tokens

func activate_arcana_by_type_async(type: Arcanum.Type, host: Node) -> Signal:
	if !host or !is_instance_valid(host):
		Events.arcana_activated.emit(type)
		return Signal()

	if type == Arcanum.Type.EVENT_BASED:
		return Signal()

	var queue: Array[Arcanum] = []
	for a in _arcana:
		if a and a.type == type:
			queue.push_back(a)

	if queue.is_empty():
		Events.arcana_activated.emit(type)
		return Signal()

	var tween := host.get_tree().create_tween()

	for a in queue:
		var ctx := ArcanumContext.new()
		ctx.api = api
		ctx.arcanum_display = _get_display(a.id) # may be null
		tween.tween_callback(a.activate_arcanum.bind(ctx))
		print("arcanum_system applying a tween interval")
		tween.tween_interval(ARCANUM_APPLY_INTERVAL)
	
	#tween.finished.connect(func():
		#Events.arcana_activated.emit(type)
	#, CONNECT_ONE_SHOT)
	
	return tween.finished
	


func activate_arcana_by_type(type: Arcanum.Type, host: Node) -> void:
	# host is required to create tweens / intervals.
	if !host or !is_instance_valid(host):
		push_warning("ArcanaSystem.activate_arcana_by_type called without a valid host Node.")
		Events.arcana_activated.emit(type)
		return

	if type == Arcanum.Type.EVENT_BASED:
		return

	var queue: Array[Arcanum] = []
	for a in _arcana:
		if a and a.type == type:
			queue.push_back(a)

	if queue.is_empty():
		Events.arcana_activated.emit(type)
		return

	var tween := host.get_tree().create_tween()

	for a in queue:
		var ctx := ArcanumContext.new()
		ctx.api = api
		ctx.arcanum_display = _get_display(a.id) # may be null; ok
		tween.tween_callback(a.activate_arcanum.bind(ctx))
		tween.tween_interval(ARCANUM_APPLY_INTERVAL)

	tween.finished.connect(func():
		Events.arcana_activated.emit(type)
	)
