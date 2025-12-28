#class_name MyNewNPCAction 
extends NPCAction

const MIGHT_STATUS = preload("res://statuses/might.tres")

@export var intensity_per_action := 5

var hp_threshold := 40
var usages := 0
