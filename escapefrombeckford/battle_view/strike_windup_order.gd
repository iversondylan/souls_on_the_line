# strike_windup_order.gd

class_name StrikeWindupOrder extends RefCounted

var duration: float = 0.20

var attacker_id: int = 0
var target_ids: Array[int] = []

var attack_mode: int = Attack.Mode.MELEE
var projectile_scene_path: String = "" # only for ranged
var projectile_spawn_ratio: float = 0.10

# attack-level multiplicity
var strike_count: int = 1
var total_hit_count: int = 1

# ordered strike data for animators
var attack_info: AttackPresentationInfo = null

# “tall + skinny”
var x_scale: float = 0.85
var y_scale: float = 1.18

# optional nudge on windup (pixels)
var drift_x: float = 6.0
