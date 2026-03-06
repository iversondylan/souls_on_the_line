# rng_util.gd
class_name RNGUtil
extends RefCounted

static func mix_seed(a: int, b: int) -> int:
	# Simple 32-bit mixing. Good enough for game RNG streams.
	var x := int(a) ^ int(b)
	x = int((x * 0x45d9f3b) & 0x7fffffff)
	x = int(((x >> 16) ^ x) & 0x7fffffff)
	return x

#static func seed_from_strings(run_seed: int, label: String) -> int:
	#return mix_seed(run_seed, label.hash())

static func fnv1a_32(s: String) -> int:
	var h: int = 0x811C9DC5
	for i in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = int((h * 0x01000193) & 0xFFFFFFFF)
	return h

static func seed_from_label(run_seed: int, label: String) -> int:
	return mix_seed(run_seed, fnv1a_32(label))
