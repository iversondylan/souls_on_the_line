class_name SoulCapacityPanel extends Control

@onready var bound_count_label: Label = $VBoxContainer/BoundHBox/Label
@onready var wild_count_label: Label = $VBoxContainer/HBoxContainer2/Label2

func set_counts(bound_count: int, bound_cap: int, wild_count: int, wild_cap: int) -> void:
	if bound_count_label != null:
		bound_count_label.text = "%d/%d" % [maxi(int(bound_count), 0), maxi(int(bound_cap), 0)]
	if wild_count_label != null:
		wild_count_label.text = "%d/%d" % [maxi(int(wild_count), 0), maxi(int(wild_cap), 0)]
