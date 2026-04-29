class_name BattleFxManager
extends Node

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
	tween.finished.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	, CONNECT_ONE_SHOT)

	return node


func ensure_on_combatant(
	key: String,
	combatant: CombatantView,
	fx_id: StringName,
	fade_in := 0.06,
	scale := DEFAULT_SCALE
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

	_attach_to_combatant(node, combatant, scale)
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
	tween.finished.connect(func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	, CONNECT_ONE_SHOT)


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


func _instance_fx(fx_id: StringName) -> Node:
	var scene: PackedScene = FxLibrary.get_named_scene(fx_id)
	if scene == null:
		return null
	var node := scene.instantiate()
	if node == null:
		return null
	return node


func _attach_to_combatant(node: Node, combatant: CombatantView, scale: float) -> void:
	combatant.add_child(node)

	if node is CanvasItem:
		(node as CanvasItem).z_index = 50

	var height := float(combatant.get_visual_height_px())
	var center := Vector2(0, -height * 0.5)
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


func _fade_to(node: Node, alpha: float, duration: float) -> Tween:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "modulate:a", alpha, maxf(duration, 0.0))
	return tween


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
