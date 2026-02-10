# sim_modifier_system.gd
class_name SimModifierSystem
extends RefCounted

var battle: SimBattle
var target_id: int

var _cache: Dictionary = {} # Modifier.Type -> ResolvedModifier
var _dirty: Dictionary = {} # Modifier.Type -> bool

func _init(_battle: SimBattle, _target_id: int) -> void:
	battle = _battle
	target_id = _target_id
	for t in Modifier.Type.values():
		_dirty[t] = true

func mark_dirty(type: Modifier.Type = Modifier.Type.NO_MODIFIER) -> void:
	if type == Modifier.Type.NO_MODIFIER:
		_cache.clear()
		_dirty.clear()
		for t in Modifier.Type.values():
			_dirty[t] = true
		return
	_dirty[type] = true
	_cache.erase(type)

func get_resolved_modifier(type: Modifier.Type) -> ResolvedModifier:
	if !_dirty.get(type, true) and _cache.has(type):
		return _cache[type]

	var resolved := ResolvedModifier.new()
	var tokens := battle.get_modifier_tokens_for_target(target_id)

	for token in tokens:
		if token.type != type:
			continue
		resolved.flat += token.flat_value
		resolved.mult *= (1.0 + token.mult_value)

	_cache[type] = resolved
	_dirty[type] = false
	return resolved
