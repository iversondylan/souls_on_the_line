# mana_panel.gd

class_name ManaPanel extends Node2D

@onready var red_radial_bar: AnimatedSprite2D = %RedRadialBar
@onready var green_radial_bar: AnimatedSprite2D = %GreenRadialBar
@onready var blue_radial_bar: AnimatedSprite2D = %BlueRadialBar

@export var red_mana: int = 3 : set = set_red_mana
@export var green_mana: int = 3 : set = set_green_mana
@export var blue_mana: int = 3 : set = set_blue_mana

func _ready() -> void:
	red_radial_bar.modulate = Color(0.572, 0.188, 0.282)
	red_mana = red_mana
	green_radial_bar.modulate = Color(0.410, 0.530, 0.188)
	green_mana = green_mana
	blue_radial_bar.modulate = Color(0.236, 0.215, 0.503)
	blue_mana = blue_mana

func set_green_mana(new_green_mana: int) -> void:
	green_mana = new_green_mana
	match green_mana:
		0:
			green_radial_bar.frame = 0
		1:
			green_radial_bar.frame = 1
		2:
			green_radial_bar.frame = 2
		3:
			green_radial_bar.frame = 3
			
func set_blue_mana(new_blue_mana: int) -> void:
	blue_mana = new_blue_mana
	match blue_mana:
		0:
			blue_radial_bar.frame = 0
		1:
			blue_radial_bar.frame = 1
		2:
			blue_radial_bar.frame = 2
		3:
			blue_radial_bar.frame = 3

func set_red_mana(new_red_mana: int) -> void:
	red_mana = new_red_mana
	match red_mana:
		0:
			red_radial_bar.frame = 0
		1:
			red_radial_bar.frame = 1
		2:
			red_radial_bar.frame = 2
		3:
			red_radial_bar.frame = 3
