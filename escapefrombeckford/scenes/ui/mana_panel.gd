# mana_panel.gd

class_name ManaPanel extends Node2D

@onready var red_radial_bar: AnimatedSprite2D = %RedRadialBar
@onready var green_radial_bar: AnimatedSprite2D = %GreenRadialBar
@onready var blue_radial_bar: AnimatedSprite2D = %BlueRadialBar
@onready var current_mana_label: Label = $CurrentManaLabel


@export var red_mana: int = 3 : set = set_red_mana
@export var green_mana: int = 3 : set = set_green_mana
@export var blue_mana: int = 3 : set = set_blue_mana

@export var color_red : Color
@export var color_green : Color
@export var color_blue : Color

func _ready() -> void:
	red_radial_bar.modulate = color_red
	red_mana = red_mana
	green_radial_bar.modulate = color_green
	green_mana = green_mana
	blue_radial_bar.modulate = color_blue
	blue_mana = blue_mana

func update_mana() -> void:
	current_mana_label.text = str(red_mana + green_mana + blue_mana)

func set_green_mana(new_green_mana: int) -> void:
	green_mana = new_green_mana
	update_mana()
	#match green_mana:
		#0:
			#green_radial_bar.frame = 0
		#1:
			#green_radial_bar.frame = 1
		#2:
			#green_radial_bar.frame = 2
		#3:
			#green_radial_bar.frame = 3
			
func set_blue_mana(new_blue_mana: int) -> void:
	blue_mana = new_blue_mana
	update_mana()
	#match blue_mana:
		#0:
			#blue_radial_bar.frame = 0
		#1:
			#blue_radial_bar.frame = 1
		#2:
			#blue_radial_bar.frame = 2
		#3:
			#blue_radial_bar.frame = 3

func set_red_mana(new_red_mana: int) -> void:
	red_mana = new_red_mana
	update_mana()
	#match red_mana:
		#0:
			#red_radial_bar.frame = 0
		#1:
			#red_radial_bar.frame = 1
		#2:
			#red_radial_bar.frame = 2
		#3:
			#red_radial_bar.frame = 3
