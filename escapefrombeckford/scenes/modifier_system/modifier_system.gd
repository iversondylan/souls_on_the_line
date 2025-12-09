class_name ModifierSystem extends Node

signal modifier_changed()

var _cache := {}              # Modifier.Type -> int
var _dirty := {}              # Modifier.Type -> bool

var dirty: bool = true

func _ready() -> void:
	for modifier: Modifier in get_children():
		modifier.modifier_changed.connect(_modifier_changed)

func has_modifier(type: Modifier.Type) -> bool:
	for modifier: Modifier in get_children():
		if modifier.type == type:
			return true
	return false
	
func get_modifier(type: Modifier.Type) -> Modifier:
	for modifier: Modifier in get_children():
		if modifier.type == type:
			return modifier
	return null

func get_modified_value(base: int, type: Modifier.Type) -> int:
	if !_dirty.get(type, true) and _cache.has(type):
		return _cache[type]

	var value := _compute_modified_value(base, type)
	_cache[type] = value
	_dirty[type] = false
	return value

func _compute_modified_value(base: int, type: Modifier.Type) -> int:
	print("modifier_system.gd _compute_modified_value() base: %s, type: %s" % [base, type])
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
	#var modifier := get_modifier(type)
	#
	#if !modifier:
		#return base
	#
	#return modifier.get_modified_value(base)

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
	if type == Modifier.Type.NO_MODIFIER:
		_dirty.clear()
	else:
		_dirty[type] = true
	
	modifier_changed.emit()
	
