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
	return resolved

func get_modifier_tokens_for(type: Modifier.Type) -> Array[ModifierToken]:
	if !run:
		return []
	
	var all_tokens: Array[ModifierToken] = run.get_modifier_tokens_for(get_parent())

	var relevant: Array[ModifierToken] = []
	for token in all_tokens:
		if token.type == type:
			relevant.append(token)
	
	return relevant

func _modifier_changed() -> void:
	modifier_changed.emit()

func mark_dirty(type: Modifier.Type = Modifier.Type.NO_MODIFIER) -> void:
	if type == Modifier.Type.NO_MODIFIER:
		_dirty.clear()
		_cache.clear()
	else:
		_dirty[type] = true
		_cache.erase(type)
	modifier_changed.emit()
