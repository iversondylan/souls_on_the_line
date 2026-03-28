class_name CardContainer extends Container

const CARD_COMPONENT_POSITION: Vector2 = Vector2(66, 94)
@onready var usable_card_scn = preload("uid://cd6j7t8hq3we3")
var usable_card: UsableCard

var card_data : CardData:
	set(_card_data):
		if !is_node_ready():
			await ready
		#remove_child(card)
		card_data = _card_data
		usable_card = usable_card_scn.instantiate()
		add_child(usable_card)
		usable_card.set_position(CARD_COMPONENT_POSITION)
		usable_card.card_data = card_data
		
# Called every frame. 'delta' is the elapsed time since the previous frame.
func clear_card():
	if usable_card:
		remove_child(usable_card)
		usable_card.queue_free()
		

func _process(_delta: float) -> void:
	pass
