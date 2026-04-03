# strike_windup_order.gd

class_name StrikeWindupOrder extends RefCounted

var duration: float = 0.20

var attacker_id: int = 0
var target_ids: Array[int] = []

var attack_mode: int = Attack.Mode.MELEE
var projectile_scene_path: String = ""

var strike_count: int = 1
var strike_index: int = 0 # <-- add this
var total_hit_count: int = 1
var chained_from_previous: bool = false
var origin_strike_index: int = -1
var chain_source_target_id: int = 0
var has_chain_continuation: bool = false

var attack_info: AttackPresentationInfo = null

var x_scale: float = 0.85
var y_scale: float = 1.18
var drift_x: float = 6.0
