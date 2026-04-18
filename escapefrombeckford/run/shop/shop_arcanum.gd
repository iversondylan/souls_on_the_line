class_name ShopArcanum extends VBoxContainer

const ARCANUM_DISPLAY_SCN = preload("uid://k1sxcd5o2me7")
const SOLD_TEXT := "Sold"
const BUY_TEXT := "Buy"
const SOLD_FONT_COLOR := Color(0.65, 0.65, 0.65, 1.0)

@export var arcanum: Arcanum : set = _set_arcanum

@onready var arcanum_container: CenterContainer = %ArcanumContainer
@onready var price: HBoxContainer = %Price
@onready var price_label: Label = %PriceLabel
@onready var buy_button: Button = %BuyButton
@export var offer_index: int = -1
@export var original_gold_cost: int = 100
var gold_cost: int = 100
var is_claimed: bool = false
var _last_run_state: RunState

func update(run_state: RunState) -> void:
	if !arcanum_container or !price or !buy_button:
		return

	_last_run_state = run_state
	_refresh_state()


func set_claimed(claimed: bool) -> void:
	is_claimed = claimed
	if !is_node_ready():
		return
	_refresh_state()


func _refresh_state() -> void:
	price_label.text = str(gold_cost)

	if is_claimed:
		price_label.add_theme_color_override("font_color", SOLD_FONT_COLOR)
		buy_button.text = SOLD_TEXT
		buy_button.disabled = true
		return

	buy_button.text = BUY_TEXT
	if _last_run_state != null and gold_cost <= _last_run_state.gold:
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
	Events.shop_arcanum_bought.emit(arcanum, gold_cost, offer_index)
