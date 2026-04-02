# attack_context.gd
class_name AttackContext extends RefCounted

var api: SimBattleAPI
var runtime: SimRuntime

var attacker_id: int = 0
var source_id: int = 0
var allow_dead_source: bool = false

var strikes: int = 1
var attack_mode: int = Attack.Mode.MELEE
var targeting: int = Attack.Targeting.STANDARD
var projectile_scene: String = ""
var targeting_ctx: TargetingContext

var base_damage: int = 0
var base_damage_melee: int = 0
var base_damage_ranged: int = 0
var base_banish_amount: int = 0
var deal_modifier_type: int = Modifier.Type.DMG_DEALT
var take_modifier_type: int = Modifier.Type.DMG_TAKEN

var params: Dictionary = {}
var tags: Array[StringName] = []
var origin_card_uid: String = ""
var origin_arcanum_id: StringName = &""
var reason: String = ""

var affected_target_ids: PackedInt32Array = PackedInt32Array()
var any_hit: bool = false
