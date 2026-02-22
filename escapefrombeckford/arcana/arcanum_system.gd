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
	if arcanum.get_id() == &"":
		return
	if has_arcanum(arcanum.get_id()):
		return

	_arcana.push_back(arcanum)
	_by_id[arcanum.get_id()] = arcanum

	if arcanum.contributes_modifier():
		for mod_type in arcanum.get_contributed_modifier_types():
			modifier_tokens_changed.emit(mod_type)

func remove_arcanum(id: StringName) -> void:
	if id == &"" or !_by_id.has(id):
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
	# host no longer needed; keep signature for now so callsites don’t explode
	print("arcanum_system.gd activate_arcana_by_type_async() type: ", Arcanum.Type.keys()[type])
	if type == Arcanum.Type.EVENT_BASED:
		return Signal()

	if !api or !api.runner:
		# No runner => just do immediate (or emit nothing). For now, no-op safely.
		return Signal()

	var queue: Array[Arcanum] = []
	for a in _arcana:
		if a and a.type == type:
			queue.push_back(a)

	if queue.is_empty():
		return Signal()

	for a in queue:
		var d := _get_display(a.get_id()) # may be null
		api.enqueue_arcanum_activate(a, d)
		api.enqueue_wait(ARCANUM_APPLY_INTERVAL)

	return Signal()

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
		ctx.arcanum_display = _get_display(a.get_id()) # may be null; ok
		tween.tween_callback(a.activate_arcanum.bind(ctx))
		tween.tween_interval(ARCANUM_APPLY_INTERVAL)

	tween.finished.connect(func():
		Events.arcana_activated.emit(type)
	)

func get_my_arcana() -> Array[StringName]:
	var arcana_ids : Array[StringName] = []
	for arcanum: Arcanum in _arcana:
		arcana_ids.push_back(arcanum.get_id())
	return arcana_ids
