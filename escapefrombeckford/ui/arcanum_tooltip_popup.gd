class_name ArcanumTooltipPopup extends Control

@onready var arcanum_icon: TextureRect = %ArcanumIcon
@onready var arcanum_description: RichTextLabel = %ArcanumDescription
@onready var arcanum_flavor: RichTextLabel = %ArcanumFlavor
@onready var arcanum_lore: RichTextLabel = %ArcanumLore

func _ready() -> void:
	Events.arcanum_popup_requested.connect(show_tooltip)
	hide()

func show_tooltip(arcanum: Arcanum) -> void:
	arcanum_icon.texture = arcanum.icon
	arcanum_description.text = arcanum.get_tooltip()
	arcanum_flavor.text = arcanum.flavor_text
	arcanum_lore.text = arcanum.lore
	show()

#func hide_tooltip() -> void:
	#if !visible:
		#return
	#
	#for card: MenuCard in tooltip_card_container.get_children():
		#card.queue_free()
	#
	#hide()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and visible:
		hide()

func _on_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("mouse_click"):
		hide()
