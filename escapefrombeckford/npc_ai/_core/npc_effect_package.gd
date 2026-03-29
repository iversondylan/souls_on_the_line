# npc_effect_package.gd

class_name NPCEffectPackage extends Resource

@export var effect: NPCEffectSequence
# Models in param_models are to modify the the params dictionary of fresh
# contexts made for this NPCEffectPackage 
@export var param_models: Array[ParamModel] = []
# Models in state_models are to modify the the state dictionary referenced
# in the action's context that belongs to the NPCAIBehavior node.
@export var state_models: Array[StateModel] = []
