# attack_now_context.gd
class_name AttackNowContext
extends RefCounted

var attacker: Fighter = null
var attacker_id: int = 0

var strikes: int = 1

# Param models that mutate NPCAIContext.params
var param_models: Array[ParamModel] = []

# Optional: override base damage computation
var base_damage: int = -1
var use_base_damage_override: bool = false

# Optional: tags (later: for logging/trigger filters)
var tags: Array[StringName] = []

# Optional: sfx
var sound: Sound = null
