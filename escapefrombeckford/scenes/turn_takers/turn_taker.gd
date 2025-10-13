class_name TurnTaker extends Node2D

signal turn_taker_turn_complete(turn_taker: TurnTaker)
@export var battle_group: BattleGroup

#THESE TWO VARS SHOULD BE REMOVED LATER
#var turn_complete: bool = false
#var doing_turn: bool = false

func enter() -> void:
	pass

func exit() -> void:
	pass

func turn_complete() -> void:
	#print("turn_taker.gd turn_complete(): %s" % name)
	turn_taker_turn_complete.emit(self as TurnTaker)
