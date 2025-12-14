class_name ModifierSystem extends Node

signal modifier_changed()

var _cache: Dictionary = {}   # Modifier.Type -> ResolvedModifier
var _dirty: Dictionary = {}   # Modifier.Type -> bool

var dirty: bool = true

func _ready() -> void:
	for type in Modifier.Type.values():
		_dirty[type] = true
	for modifier: Modifier in get_children():
		modifier.modifier_changed.connect(_modifier_changed)

#func has_modifier(type: Modifier.Type) -> bool:
	#for modifier: Modifier in get_children():
		#if modifier.type == type:
			#return true
	#return false
	
#func get_modifier(type: Modifier.Type) -> Modifier:
	#for modifier: Modifier in get_children():
		#if modifier.type == type:
			#return modifier
	#return null

func get_modified_value(base: int, type: Modifier.Type) -> int:
	var mod := get_resolved_modifier(type)
	return floori((base + mod.flat) * mod.mult)

func _build_resolved_modifier(type: Modifier.Type) -> ResolvedModifier:
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
	var tokens: Array[ModifierToken] = []

	if owner == null:
		return tokens

	# --- BATTLE CONTEXT ---
	if owner is Fighter and owner.battle_scene:
		for token in owner.battle_scene.get_modifier_tokens_for(owner):
			if token.type == type:
				tokens.append(token)
		return tokens

	# --- SHOP CONTEXT ---
	if owner is Shop:
		# Arcana-driven shop modifiers
		if owner.arcana_system:
			for arcanum: Arcanum in owner.arcana_system.get_all_arcana():
				if arcanum.contributes_modifier():
					for token in arcanum.get_modifier_tokens():
						if token.type == type:
							tokens.append(token)
		return tokens

	# --- RUN / PLAYER CONTEXT (future-proofing) ---
	if owner.has_method("get_modifier_tokens"):
		for token in owner.get_modifier_tokens():
			if token.type == type:
				tokens.append(token)

	return tokens

#func get_modifier_tokens_for(type: Modifier.Type) -> Array[ModifierToken]:
	#if !owner or !owner.battle_scene:
		#return []
#
	#var all_tokens: Array[ModifierToken] = owner.battle_scene.get_modifier_tokens_for(owner)
	#var relevant: Array[ModifierToken] = []
#
	#for token in all_tokens:
		#if token.type == type:
			#relevant.append(token)
#
	#return relevant


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
	
