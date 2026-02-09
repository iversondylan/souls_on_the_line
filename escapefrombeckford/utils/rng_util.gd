# rng_util.gd (autoload or utility)
class_name RNGUtil
extends RefCounted

static func mix_seed(a: int, b: int) -> int:
	# Simple 32-bit mixing. Good enough for game RNG streams.
	var x := int(a) ^ int(b)
	x = int((x * 0x45d9f3b) & 0x7fffffff)
	x = int(((x >> 16) ^ x) & 0x7fffffff)
	return x

static func seed_from_strings(run_seed: int, label: String) -> int:
	return mix_seed(run_seed, label.hash())
