class_name BattleFxManager
extends Node2D

const DEFAULT_FADE_IN := 0.04
const DEFAULT_HOLD := 0.0
const DEFAULT_FADE_OUT := 0.3
const DEFAULT_SCALE := 1.05

var _persistent: Dictionary = {}


func play_on_combatant(
	combatant: CombatantView,
	fx_id: StringName,
	fade_in := DEFAULT_FADE_IN,
	hold := DEFAULT_HOLD,
	fade_out := DEFAULT_FADE_OUT,
	scale := DEFAULT_SCALE
) -> Node:
	var node := _instance_fx(fx_id)
	if node == null or combatant == null or !is_instance_valid(combatant):
		return null

	_attach_to_combatant(node, combatant, scale)
	_set_alpha(node, 0.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", 1.0, maxf(fade_in, 0.0))
	if hold > 0.0:
		tween.tween_interval(hold)
	tween.tween_property(node, "modulate:a", 0.0, maxf(fade_out, 0.0))
	_queue_free_when_finished(tween, node)

	return node


func ensure_on_combatant(
	key: String,
	combatant: CombatantView,
	fx_id: StringName,
	fade_in := 0.06,
	scale := DEFAULT_SCALE,
	center_y_ratio := 0.5
) -> Node:
	if key.is_empty() or combatant == null or !is_instance_valid(combatant):
		return null

	var existing: Dictionary = _persistent.get(key, {})
	var existing_node: Node = existing.get(&"node", null)
	var existing_combatant: CombatantView = existing.get(&"combatant", null)
	var existing_fx: StringName = existing.get(&"fx_id", &"")
	if (
		existing_node != null
		and is_instance_valid(existing_node)
		and existing_combatant == combatant
		and existing_fx == fx_id
	):
		var existing_tween: Tween = existing.get(&"tween", null)
		if existing_tween != null:
			existing_tween.kill()
		_persistent[key][&"tween"] = _fade_to(existing_node, 1.0, fade_in)
		return existing_node

	_clear_key_immediate(key)

	var node := _instance_fx(fx_id)
	if node == null:
		return null

	_attach_to_combatant(node, combatant, scale, center_y_ratio)
	_set_alpha(node, 0.0)
	var tween := _fade_to(node, 1.0, fade_in)
	_persistent[key] = {
		&"node": node,
		&"combatant": combatant,
		&"fx_id": fx_id,
		&"tween": tween,
	}
	if !combatant.tree_exiting.is_connected(_on_combatant_tree_exiting.bind(combatant)):
		combatant.tree_exiting.connect(_on_combatant_tree_exiting.bind(combatant))
	return node


func clear_key(key: String, fade_out := 0.06) -> void:
	if key.is_empty() or !_persistent.has(key):
		return

	var entry: Dictionary = _persistent[key]
	_persistent.erase(key)
	var node: Node = entry.get(&"node", null)
	if node == null or !is_instance_valid(node):
		return

	var old_tween: Tween = entry.get(&"tween", null)
	if old_tween != null:
		old_tween.kill()

	var tween := _fade_to(node, 0.0, fade_out)
	_queue_free_when_finished(tween, node)


func clear_for_combatant(combatant: CombatantView, fade_out := 0.0) -> void:
	if combatant == null:
		return
	var keys: Array[String] = []
	for key in _persistent.keys():
		var entry: Dictionary = _persistent[key]
		if entry.get(&"combatant", null) == combatant:
			keys.append(String(key))
	for key in keys:
		if fade_out > 0.0:
			clear_key(key, fade_out)
		else:
			_clear_key_immediate(key)


func play_at_global_position(
	fx_id: StringName,
	global_pos: Vector2,
	size := Vector2(180, 180)
) -> Node:
	var node := _instance_fx(fx_id)
	if node == null:
		return null

	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		control.size = size
		control.pivot_offset = size * 0.5
		control.position = to_local(global_pos) - size * 0.5
		add_child(node)
	elif node is Node2D:
		# Configure size and position BEFORE add_child so _ready() fires with correct state.
		# One-shot particle effects emit immediately in _ready, so position must be set first.
		if node.has_method("configure_fx"):
			node.call("configure_fx", size)
		(node as Node2D).position = to_local(global_pos)
		add_child(node)
	else:
		add_child(node)

	return node


func _instance_fx(fx_id: StringName) -> Node:
	var scene: PackedScene = FxLibrary.get_named_scene(fx_id)
	if scene == null:
		return null
	var node := scene.instantiate()
	if node == null:
		return null
	return node


func _attach_to_combatant(node: Node, combatant: CombatantView, scale: float, center_y_ratio := 0.5) -> void:
	_add_combatant_fx_child_below_art(combatant, node)

	var height := float(combatant.get_visual_height_px())
	var center := Vector2(0, -height * clampf(center_y_ratio, 0.0, 1.0))
	if node is Control:
		var control := node as Control
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var original_size := control.size
		if original_size.x <= 0.0 or original_size.y <= 0.0:
			original_size = Vector2(128, 128)
		var max_dim := maxf(original_size.x, original_size.y)
		var target_max := maxf(height * scale, 1.0)
		var final_size := original_size * (target_max / max_dim)
		control.size = final_size
		control.pivot_offset = final_size * 0.5
		control.position = center - final_size * 0.5
	elif node is Node2D:
		(node as Node2D).position = center


func _add_combatant_fx_child_below_art(combatant: CombatantView, node: Node) -> void:
	combatant.add_child(node)
	var art_parent := combatant.get_node_or_null("ArtParent")
	if art_parent != null:
		combatant.move_child(node, art_parent.get_index())
	else:
		combatant.move_child(node, 0)


func _fade_to(node: Node, alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", alpha, maxf(duration, 0.0))
	return tween


func _queue_free_when_finished(tween: Tween, node: Node) -> void:
	if tween == null or node == null:
		return
	var node_ref: WeakRef = weakref(node)
	tween.finished.connect(func() -> void:
		var live_node := node_ref.get_ref() as Node
		if live_node != null and is_instance_valid(live_node):
			live_node.queue_free()
	, CONNECT_ONE_SHOT)


func _set_alpha(node: Node, alpha: float) -> void:
	if "modulate" in node:
		var color: Color = node.modulate
		color.a = alpha
		node.modulate = color


func _clear_key_immediate(key: String) -> void:
	if !_persistent.has(key):
		return
	var entry: Dictionary = _persistent[key]
	_persistent.erase(key)
	var tween: Tween = entry.get(&"tween", null)
	if tween != null:
		tween.kill()
	var node: Node = entry.get(&"node", null)
	if node != null and is_instance_valid(node):
		node.queue_free()


func _on_combatant_tree_exiting(combatant: CombatantView) -> void:
	clear_for_combatant(combatant)
