class_name ShopArcanum extends VBoxContainer

const ARCANUM_DISPLAY_SCN = preload("res://arcana/arcanum_display.tscn")

@export var arcanum: Arcanum : set = _set_arcanum

@onready var arcanum_container: CenterContainer = %ArcanumContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@onready var original_gold_cost := randi_range(100, 300)
@onready var gold_cost: int = original_gold_cost

func update(run_state: RunState) -> void:
	if !arcanum_container or !price or !buy_button:
		return
	
	price_label.text = str(gold_cost)
	
	if run_state != null and gold_cost <= run_state.gold:
		price_label.remove_theme_color_override("font_color")
		buy_button.disabled = false
	else:
		price_label.add_theme_color_override("font_color", Color.RED)
		buy_button.disabled = true

func _set_arcanum(new_arcanum: Arcanum) -> void:
	if !is_node_ready():
		await ready
	
	arcanum = new_arcanum
	
	for arcanum_display: ArcanumDisplay in arcanum_container.get_children():
		arcanum_display.queue_free()
	
	var new_arcanum_display := ARCANUM_DISPLAY_SCN.instantiate() as ArcanumDisplay
	arcanum_container.add_child(new_arcanum_display)
	new_arcanum_display.arcanum = arcanum

func _on_buy_button_pressed() -> void:
	Events.shop_arcanum_bought.emit(arcanum, gold_cost)
	arcanum_container.queue_free()
	price.queue_free()
	buy_button.queue_free()
