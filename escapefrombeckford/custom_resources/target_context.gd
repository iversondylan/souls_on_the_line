# target_context.gd
class_name TargetContext extends RefCounted

var source: Fighter        # who is acting
var action: NPCAction      # NPAction or attack_effect (whatever you prefer)
var base_target: Fighter   # default target (e.g. front enemy)
var final_target: Fighter  # starts as base_target, then gets modified
