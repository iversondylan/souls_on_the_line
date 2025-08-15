class_name Combatant extends Node2D

signal target_area_area_entered(area: Area2D)
signal target_area_area_exited(area: Area2D)

@onready var character_sprite: Sprite2D = $CharacterArt
@onready var target_area: CombatantTargetArea = $TargetArea
@onready var targeted_arrow: Sprite2D = $TargetedArrow
@onready var health_bar: ProgressBar = $HealthBar
@onready var armor_sprite: Sprite2D = $Armor
@onready var armor_label: Label = $Armor/Label
@onready var status_bar: IconViewPanel = %StatusBar
@onready var intent_container: IconViewPanel = $IconViewPanel
@onready var area_left: CombatantAreaLeft = $AreaLeft



func _on_target_area_area_entered(area: Area2D) -> void:
	target_area_area_entered.emit(area)


func _on_target_area_area_exited(area: Area2D) -> void:
	target_area_area_exited.emit(area)
