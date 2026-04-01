# attack_analysis.gd

class_name AttackAnalysis extends RefCounted

var attacker_id: int = 0
var attack_mode: int = Attack.Mode.MELEE
var projectile_scene_path: String = ""
var strike_count: int = 0
var strikes: Array[StrikePresentationInfo] = []
var lethal_indices: PackedInt32Array = [] # A single-target triple attack could have up to 3 kills
