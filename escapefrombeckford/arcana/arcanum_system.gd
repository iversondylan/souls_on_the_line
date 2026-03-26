# arcanum_system.gd
class_name ArcanaSystem extends RefCounted

signal modifier_tokens_changed(mod_type: Modifier.Type)

const ARCANUM_APPLY_INTERVAL := 0.5

var api: SimBattleAPI = null

# Ordered list (for display ordering)
var _arcana: Array[Arcanum] = []

# id -> Arcanum
var _by_id: Dictionary = {}

# id -> WeakRef(ArcanumDisplay)
var _display_by_id: Dictionary = {}

#func set_api(new_api: LiveBattleAPI) -> void:
	#api = new_api

func bind_display(arcanum_id: StringName, display: Node) -> void:
	if arcanum_id == &"" or display == null:
		return
	_display_by_id[arcanum_id] = weakref(display)

func unbind_display(arcanum_id: StringName) -> void:
	_display_by_id.erase(arcanum_id)

func _get_display(arcanum_id: StringName) -> ArcanumDisplay:
	var wr : WeakRef = _display_by_id.get(arcanum_id, null)
	if wr == null:
		return null
	var d : ArcanumDisplay = wr.get_ref()
	if d == null or !is_instance_valid(d):
		return null
	return d as ArcanumDisplay


func play_view_activation(arcanum_id: StringName, _proc: int, _source_id: int) -> void:
	if arcanum_id == &"" or !_by_id.has(arcanum_id):
		return

	var d := _get_display(arcanum_id)
	if d == null:
		return

	d.flash()

func on_reward_context_started(ctx: RewardContext) -> void:
	if ctx == null:
		return
	for a in _arcana:
		if a != null:
			a.on_reward_context_started(ctx)

func on_shop_context_started(ctx: ShopContext) -> void:
	if ctx == null:
		return
	for a in _arcana:
		if a != null:
			a.on_shop_context_started(ctx)

func has_arcanum(id: StringName) -> bool:
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

#func activate_arcana_by_type_async(type: Arcanum.Type, host: Node) -> Signal:
	## host no longer needed; keep signature for now so callsites don’t explode
	##print("arcanum_system.gd activate_arcana_by_type_async() type: ", Arcanum.Type.keys()[type])
	#if type == Arcanum.Type.EVENT_BASED:
		#return Signal()
#
	#if !api or !api.runner:
		## No runner => just do immediate (or emit nothing). For now, no-op safely.
		#return Signal()
#
	#var queue: Array[Arcanum] = []
	#for a in _arcana:
		#if a and a.type == type:
			#queue.push_back(a)
#
	#if queue.is_empty():
		#return Signal()
#
	#for a in queue:
		#var d := _get_display(a.get_id()) # may be null
		#api.enqueue_arcanum_activate(a, d)
		#api.enqueue_wait(ARCANUM_APPLY_INTERVAL)
#
	#return Signal()

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
		tween.tween_callback(_activate_arcana_by_type_now.bind(a, type))
		tween.tween_interval(ARCANUM_APPLY_INTERVAL)

	tween.finished.connect(func():
		Events.arcana_activated.emit(type)
	)

func get_my_arcana() -> Array[StringName]:
	#print("arcanum_syste.gd get_my_arcana")
	var arcana_ids : Array[StringName] = []
	for arcanum: Arcanum in _arcana:
		#print(arcanum.get_id())
		arcana_ids.push_back(arcanum.get_id())
	return arcana_ids

func _activate_arcana_by_type_now(arcanum: Arcanum, type: Arcanum.Type) -> void:
	if arcanum == null or api == null:
		return

	match int(type):
		Arcanum.Type.START_OF_COMBAT:
			arcanum.on_battle_started(api)
		Arcanum.Type.START_OF_TURN:
			arcanum.on_turn_started(api)
		Arcanum.Type.END_OF_TURN:
			arcanum.on_turn_ended(api)
		Arcanum.Type.END_OF_COMBAT:
			arcanum.on_battle_ended(api)
