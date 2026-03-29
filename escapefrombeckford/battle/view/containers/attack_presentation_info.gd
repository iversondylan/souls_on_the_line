# attack_presentation_info.gd

class_name AttackPresentationInfo extends RefCounted

var attacker_id: int = 0
var attack_mode: int = Attack.Mode.MELEE

# shared presentation metadata
var projectile_scene_path: String = ""
var strike_count: int = 0
var total_hit_count: int = 0
var has_lethal_hit: bool = false

# normalized timing across the whole phase that consumes this attack
# usually windup/followthrough readers will interpret these
var t0_ratio: float = 0.0
var t1_ratio: float = 1.0

var strikes: Array[StrikePresentationInfo] = []


func get_all_target_ids() -> Array[int]:
	var out: Array[int] = []
	var seen := {}
	for s in strikes:
		if s == null:
			continue
		for tid in s.target_ids:
			var k := int(tid)
			if seen.has(k):
				continue
			seen[k] = true
			out.append(k)
	return out


func is_multistrike() -> bool:
	return strikes.size() > 1
