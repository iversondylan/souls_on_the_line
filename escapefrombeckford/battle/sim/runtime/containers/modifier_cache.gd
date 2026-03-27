# modifier_cache.gd

class_name ModifierCache extends RefCounted

# This is a *cache*, not a live system.
# Rebuild it when something changes (status added/removed, aura changes, etc.).

# modifier_type -> flat_add
var add: Dictionary = {} # int -> int

# modifier_type -> multiplier (float)
var mul: Dictionary = {} # int -> float

func clear() -> void:
	add.clear()
	mul.clear()

func set_add(mod_type: int, value: int) -> void:
	add[mod_type] = int(value)

func set_mul(mod_type: int, value: float) -> void:
	mul[mod_type] = float(value)

func get_add(mod_type: int) -> int:
	return int(add.get(mod_type, 0))

func get_mul(mod_type: int) -> float:
	return float(mul.get(mod_type, 1.0))

func apply(mod_type: int, base: int) -> int:
	# (base + add) * mul
	var v := float(base + get_add(mod_type)) * get_mul(mod_type)
	return int(round(v))

func clone() -> ModifierCache:
	var m := ModifierCache.new()
	m.add = add.duplicate(true)
	m.mul = mul.duplicate(true)
	return m
