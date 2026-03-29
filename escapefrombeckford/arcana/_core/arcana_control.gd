class_name ArcanaControl extends Control

const ARCANA_PER_PAGE := 7
const TWEEN_SCROLL_DURATION := 0.2

@export var left_button: TextureButton
@export var right_button: TextureButton

@onready var arcana_container: HBoxContainer = %ArcanaContainer
@onready var page_width = self.custom_minimum_size.x

var n_arcana := 0
var current_page := 1
var max_page := 0
var tween: Tween

func _ready() -> void:
	left_button.pressed.connect(_on_left_button_pressed)
	right_button.pressed.connect(_on_right_button_pressed)
	
	for arcanum_display: ArcanumDisplay in arcana_container.get_children():
		arcanum_display.free()
	
	arcana_container.child_order_changed.connect(_on_arcana_child_order_changed)
	_on_arcana_child_order_changed()

func update() -> void:
	if !is_instance_valid(right_button):
		return
	n_arcana = arcana_container.get_child_count()
	max_page = ceili(n_arcana / float(ARCANA_PER_PAGE))
	
	left_button.disabled = current_page <= 1
	right_button.disabled = current_page >= max_page

func _tween_to(x_position: float) -> void:
	if tween:
		tween.kill()
	
	tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(arcana_container, "position:x", x_position, TWEEN_SCROLL_DURATION)

func _on_left_button_pressed() -> void:
	if current_page > 1:
		current_page -= 1
		update()
		_tween_to(arcana_container.position.x + page_width)

func _on_right_button_pressed() -> void:
	if current_page < max_page:
		current_page += 1
		update()
		_tween_to(arcana_container.position.x - page_width)

func _on_arcana_child_order_changed() -> void:
	update()
