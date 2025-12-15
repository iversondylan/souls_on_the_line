class_name ModifierSystem extends Node

signal modifier_changed()

var _cache: Dictionary = {}   # Modifier.Type -> ResolvedModifier
var _dirty: Dictionary = {}   # Modifier.Type -> bool

var dirty: bool = true

var run: Run

func _ready() -> void:
	for type in Modifier.Type.values():
		_dirty[type] = true
	for modifier: Modifier in get_children():
		modifier.modifier_changed.connect(_modifier_changed)

func get_modified_value(base: int, type: Modifier.Type) -> int:
	print("modifier_system.gd get_modified_value() owner: %s base: %s, type: %s" % [get_parent(), base, Modifier.Type.keys()[type]])
	print("run is: %s" % run)
	var mod := get_resolved_modifier(type)
	print("modified value: %s" % floori((base + mod.flat) * mod.mult))
	return floori((base + mod.flat) * mod.mult)

func _build_resolved_modifier(type: Modifier.Type) -> ResolvedModifier:
	print("_build_resolved_modifier()")
	var result := ResolvedModifier.new()

	for token in get_modifier_tokens_for(type):
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
	print("get_modifier_tokens_for()")
	if !run:
		print("no run")
		return []

	var all_tokens: Array[ModifierToken] = run.get_modifier_tokens_for(owner)
	var relevant: Array[ModifierToken] = []
	for token in all_tokens:
		if token.type == type:
			relevant.append(token)

	return relevant

func _compute_modified_value(base: int, type: Modifier.Type) -> int:
	#print("modifier_system.gd _compute_modified_value() base: %s, type: %s" % [base, type])
	var tokens := get_parent().get_modifier_tokens() as Array[ModifierToken]
	var applicable: Array[ModifierToken] = []

	for token in tokens:
		if token.type != type:
			continue
		if !_token_applies(token):
			continue
		applicable.append(token)

	return _apply_tokens(base, applicable)

func _token_applies(token: ModifierToken) -> bool:
	match token.scope:
		ModifierToken.Scope.SELF:
			return token.owner == get_parent()
		ModifierToken.Scope.GLOBAL:
			return true
		ModifierToken.Scope.TARGET:
			return false # defer
	return false

func _apply_tokens(base: int, tokens: Array[ModifierToken]) -> int:
	var flat := base
	var mult := 1.0

	tokens.sort_custom(func(a, b): return a.priority < b.priority)

	for token in tokens:
		flat += token.flat_value

	for token in tokens:
		mult += token.mult_value

	return floori(flat * mult)

func _modifier_changed() -> void:
	modifier_changed.emit()

func mark_dirty(type: Modifier.Type = Modifier.Type.NO_MODIFIER) -> void:
	print("modifier_system.gd mark_dirty() type: %s" % Modifier.Type.keys()[type])
	if type == Modifier.Type.NO_MODIFIER:
		_dirty.clear()
	else:
		_dirty[type] = true
	
	modifier_changed.emit()
	
