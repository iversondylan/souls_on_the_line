class_name NPCAction extends Node

signal action_performed(npc_action: NPCAction)

enum ChoiceType {CONDITIONAL, CHANCE}
enum ActionCode {TIGER, TURTLE, TURKEY, TOUCAN, TARSIER, TAPIR}

@export var intent_icon: IconData
@export var sound: AudioStream
@export var choice_type: ChoiceType
@export var code_type: ActionCode
@export_range(0.0, 10.0) var chance_weight: float = 0.0
@onready var accumulated_weight: float = 0.0

var combatant: NPCFighter
var target: Fighter
var player: Player
var battle_scene: BattleScene

func is_performable() -> bool:
	return false

func perform_action() -> void:
	pass

func update_action_intent() -> void:
	pass

func other_action_performed(npc_action: NPCAction) -> void:
	pass
