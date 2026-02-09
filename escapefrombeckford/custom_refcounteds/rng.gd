# rng.gd
class_name RNG
extends RefCounted

var seed: int
var rolls: int = 0

func _init(_seed: int = 1) -> void:
	seed = _seed

func _base_rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

func randf() -> float:
	var r := _base_rng()
	for i in range(rolls):
		r.randf()
	rolls += 1
	return r.randf()

func randi() -> int:
	var r := _base_rng()
	for i in range(rolls):
		r.randi()
	rolls += 1
	return r.randi()

func clone() -> RNG:
	var c := RNG.new(seed)
	c.rolls = rolls
	return c
