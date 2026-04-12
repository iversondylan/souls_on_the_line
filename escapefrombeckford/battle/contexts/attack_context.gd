# attack_context.gd
class_name AttackContext extends RefCounted

enum ResolutionKind {
	NONE,
	PRIMARY_STRIKE,
	CLEAVE,
}

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
var killed_target_ids: PackedInt32Array = PackedInt32Array()
var any_hit: bool = false
var current_strike_index: int = -1
var current_primary_target_ids: Array[int] = []
var current_cleave_target_id: int = 0
var current_cleave_damage: int = 0
var current_resolution_kind: int = ResolutionKind.NONE
