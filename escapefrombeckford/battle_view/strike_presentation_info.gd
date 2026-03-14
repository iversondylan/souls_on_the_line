# strike_presentation_info.gd

class_name StrikePresentationInfo extends RefCounted

var attacker_id: int = 0
var target_ids: Array[int] = []
var attack_mode: int = Attack.Mode.MELEE

var hit_count: int = 1
var target_count: int = 1
var has_lethal: bool = false
var lethal_target_ids: Array[int] = []

var projectile_scene_path: String = ""
var projectile_spawn_ratio: float = 0.10
var projectile_impact_ratio: float = 0.0
