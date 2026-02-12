# attack_target_context.gd

class_name AttackTargetContext extends RefCounted

var api: BattleAPI
var source_id: int = 0
var params: Dictionary = {}

var base_target_ids: Array[int] = []
var final_target_ids: Array[int] = []

var is_single_target_intent: bool = false

#class_name AttackTargetContext extends RefCounted
#var api: BattleAPI
#var source: Fighter        # who is acting
##var effect: AttackEffect
##var attack_effect: NPCAttackEffect #<---- NEW
#var params: Dictionary = {}
#var base_targets: Array[Fighter]   # default target (e.g. front enemy)
#var final_targets: Array[Fighter]  # starts as base_target, then gets modified
#var is_single_target_intent: bool
