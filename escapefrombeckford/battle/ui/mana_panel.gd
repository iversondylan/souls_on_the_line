# mana_panel.gd

class_name ManaPanel extends Control

@onready var current_mana_label: Label = $CurrentManaLabel

@export var mana: int = 3 : set = set_mana

func _ready() -> void:
	update_mana()

func update_mana() -> void:
	current_mana_label.text = str(mana)

func set_mana(new_mana: int) -> void:
	mana = new_mana
	update_mana()
