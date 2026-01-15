# modifier_system.gd
class_name ModifierSystem extends Node

signal modifier_changed()

var _cache: Dictionary = {}   # Modifier.Type -> ResolvedModifier
var _dirty: Dictionary = {}   # Modifier.Type -> bool

var run: Run

func _ready() -> void:
	for type in Modifier.Type.values():
		_dirty[type] = true

func get_modified_value(base: int, type: Modifier.Type) -> int:
	var mod := get_resolved_modifier(type)
	return floori((base + mod.flat) * mod.mult)

func _build_resolved_modifier(type: Modifier.Type) -> ResolvedModifier:
	var result := ResolvedModifier.new()
	var tokens := get_modifier_tokens_for(type)

	if type == Modifier.Type.DMG_DEALT:
		print("\n--- BUILD DMG_DEALT for:", owner.name)
		for t in tokens:
			print(" token:", t.source_id,
				" owner:", t.owner.name if t.owner else "null",
				" scope:", t.scope,
				" flat:", t.flat_value,
				" tags:", t.tags)

	for token in tokens:
		result.flat += token.flat_value
		result.mult *= (1.0 + token.mult_value)
	return result

func get_resolved_modifier(type: Modifier.Type) -> ResolvedModifier:
	if !_dirty.get(type, true) and _cache.has(type):
		return _cache[type]

	var resolved := _build_resolved_modifier(type)
	_cache[type] = resolved
	_dirty[type] = false
	print("modifier_system.gd get_resolved_modifier() resolved flat: ", resolved.flat, " mult: ", resolved.mult)
	return resolved

func get_modifier_tokens_for(type: Modifier.Type) -> Array[ModifierToken]:
	if !run:
		return []
	
	var all_tokens: Array[ModifierToken] = run.get_modifier_tokens_for(owner)
	var relevant: Array[ModifierToken] = []
	for token in all_tokens:
		if token.type == type:
			relevant.append(token)
	
	return relevant

func _modifier_changed() -> void:
	modifier_changed.emit()

func mark_dirty(type: Modifier.Type = Modifier.Type.NO_MODIFIER) -> void:
	print("_cache before: ", _cache, " name: ", get_parent().name)
	print("marking dirty mod type: %s" % Modifier.Type.keys()[type])
	if type == Modifier.Type.NO_MODIFIER:
		print("Modifier.Type.NO_MODIFIER")
		_dirty.clear()
		_cache.clear()
	else:
		print("Modifier.Type ~other")
		_dirty[type] = true
		_cache.erase(type)
	print("_cache after: ", _cache, " name: ", get_parent().name)
	modifier_changed.emit()
