# sim_attack_spec.gd

class_name SimAttackSpec extends RefCounted

var attacker_id: int = 0

# How many strikes (each strike can hit multiple targets depending on targeting)
var strikes: int = 1

# Raw base damage; modifiers are applied inside damage resolver (via DamageContext types)
var base_damage: int = 0
var deal_modifier_type: int = Modifier.Type.DMG_DEALT
var take_modifier_type: int = Modifier.Type.DMG_TAKEN

# Params used by AttackTargeting + any later conditional logic
var params: Dictionary = {}

# Optional: explicit targets override targeting (useful for some AttackNow designs)
var explicit_target_ids: Array[int] = []

# Optional: tags for downstream procs/logging
var tags: Array[StringName] = []
