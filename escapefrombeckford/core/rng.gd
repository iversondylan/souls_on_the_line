# rng.gd

class_name RNG
extends RefCounted

var rng_seed: int = 1
var rolls: int = 0

var _rng: RandomNumberGenerator

func _init(_seed: int = 1, _rolls: int = 0) -> void:
	rng_seed = _seed
	rolls = _rolls
	_rng = RandomNumberGenerator.new()
	_rng.seed = rng_seed
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
	return RNG.new(rng_seed, rolls)

func snapshot() -> Dictionary:
	return {"seed": seed, "rolls": rolls}

static func from_snapshot(d: Dictionary) -> RNG:
	return RNG.new(int(d.get("seed", 1)), int(d.get("rolls", 0))) 

func debug_randf(_tag: String = "") -> float:
	var _before := rolls
	var v := randf()
	#print("[RNG] %s seed=%d roll=%d -> randf=%s" % [tag, seed, before, str(v)])
	return v

func debug_randi(_tag: String = "") -> int:
	var _before := rolls
	var v := randi()
	#print("[RNG] %s seed=%d roll=%d -> randi=%d" % [tag, seed, before, v])
	return v

func debug_range_i(lo: int, hi: int, _tag: String = "") -> int:
	var _before := rolls
	var v := _rng.randi_range(lo, hi)
	rolls += 1
	#print("[RNG] %s seed=%d roll=%d -> randi_range(%d,%d)=%d" % [tag, seed, before, lo, hi, v])
	return v

func debug_range_f(lo: float, hi: float, _tag: String = "") -> float:
	var _before := rolls
	var v := _rng.randf_range(lo, hi)
	rolls += 1
	#print("[RNG] %s seed=%d roll=%d -> randf_range(%s,%s)=%s" % [tag, seed, before, str(lo), str(hi), str(v)])
	return v
