class_name NPCAction extends Node

signal action_performed(npc_action: NPCAction)

enum ChoiceType {CONDITIONAL, CHANCE}
enum ActionCode {TIGER, TURTLE, TURKEY, TOUCAN, TARSIER, TAPIR}

@export var base_intent_data: IntentData
@export var sound: AudioStream
@export var choice_type: ChoiceType
@export var code_type: ActionCode
@export_range(0.0, 10.0) var chance_weight: float = 0.0
@onready var accumulated_weight: float = 0.0
var intent_data: IntentData

var combatant: Fighter : set = set_fighter
var target: Fighter
var player: Player
var battle_scene: BattleScene

func _ready() -> void:
	intent_data = base_intent_data.duplicate()
	intent_data.action = self

func is_performable() -> bool:
	return false

func perform_action() -> void:
	pass

func update_action_intent() -> void:
	pass

func other_action_performed(_npc_action: NPCAction) -> void:
	pass

func set_fighter(new_fighter: Fighter) -> void:
	combatant = new_fighter

func get_tooltip() -> String:
	return "error"
#func update_tooltip() -> String:
	#return intent_data.tooltip_text
#func update_intent_text() -> void:
	#intent_data.current_text = intent_data.base_text
