# npc_action.gd
class_name NPCAction extends Resource

enum ChoiceType { CONDITIONAL, CHANCE }

@export var effect_packages: Array[NPCEffectPackage]
@export var intent_lifecycle_models: Array[IntentLifecycleModel]

@export_group("Selection")
@export var choice_type: ChoiceType = ChoiceType.CHANCE
@export var chance_weight: float = 1.0
@export var performable_models: Array[PerformableModel]
@export var state_models: Array[StateModel]

@export_group("Intent")
@export var intent_icon: Texture2D
@export var intent_icon_uid: String
@export var intent_icon_ranged: Texture2D
@export var intent_icon_ranged_uid: String
@export var intent_text_model: TextModel
@export var tooltip_model: TextModel

@export_group("Resolution Impact")
#@export var sound: AudioStream
@export var resolve_delay: float = 0.6
