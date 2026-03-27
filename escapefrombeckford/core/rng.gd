# rng.gd

class_name RNG
extends RefCounted

var seed: int = 1
var rolls: int = 0

var _rng: RandomNumberGenerator

func _init(_seed: int = 1, _rolls: int = 0) -> void:
	seed = _seed
	rolls = _rolls
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed
	# fast-forward if rehydrated
	for i in range(rolls):
		_rng.randi()

func randf() -> float:
	rolls += 1
	return _rng.randf()

func randi() -> int:
	rolls += 1
	return _rng.randi()

func clone() -> RNG:
	return RNG.new(seed, rolls)

func snapshot() -> Dictionary:
	return {"seed": seed, "rolls": rolls}

static func from_snapshot(d: Dictionary) -> RNG:
	return RNG.new(int(d.get("seed", 1)), int(d.get("rolls", 0))) 

#class_name RNG
#extends RefCounted
#
#var seed: int
#var rolls: int = 0
#
#func _init(_seed: int = 1) -> void:
	#seed = _seed
#
#func _base_rng() -> RandomNumberGenerator:
	#var r := RandomNumberGenerator.new()
	#r.seed = seed
	#return r
#
## later: store an internal RandomNumberGenerator 
## and advance it incrementally, but still make it 
## snapshotable by storing {seed, rolls} and rehydrating 
## when needed. For now, this is correct and very “debuggable.”
#
#func randf() -> float:
	#var r := _base_rng()
	#for i in range(rolls):
		#r.randf()
	#rolls += 1
	#return r.randf()
#
#func randi() -> int:
	#var r := _base_rng()
	#for i in range(rolls):
		#r.randi()
	#rolls += 1
	#return r.randi()
#
#func clone() -> RNG:
	#var c := RNG.new(seed)
	#c.rolls = rolls
	#return c

func debug_randf(tag: String = "") -> float:
	var before := rolls
	var v := randf()
	#print("[RNG] %s seed=%d roll=%d -> randf=%s" % [tag, seed, before, str(v)])
	return v

func debug_randi(tag: String = "") -> int:
	var before := rolls
	var v := randi()
	#print("[RNG] %s seed=%d roll=%d -> randi=%d" % [tag, seed, before, v])
	return v

func debug_range_i(lo: int, hi: int, tag: String = "") -> int:
	var before := rolls
	var v := _rng.randi_range(lo, hi)
	rolls += 1
	#print("[RNG] %s seed=%d roll=%d -> randi_range(%d,%d)=%d" % [tag, seed, before, lo, hi, v])
	return v

func debug_range_f(lo: float, hi: float, tag: String = "") -> float:
	var before := rolls
	var v := _rng.randf_range(lo, hi)
	rolls += 1
	#print("[RNG] %s seed=%d roll=%d -> randf_range(%s,%s)=%s" % [tag, seed, before, str(lo), str(hi), str(v)])
	return v
