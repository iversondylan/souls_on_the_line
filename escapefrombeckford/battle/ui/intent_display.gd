class_name IntentDisplay extends Control
var intent_data: IntentData
@onready var text: Label = $Text
@onready var icon: TextureRect = $Icon

func _ready() -> void:
	pass

func _exit_tree() -> void:
	Events.tooltip_source_exited.emit(self)

func load_icon_data(_intent_data: IntentData):
	intent_data = _intent_data
	set_icon_values()

func set_icon_values():
	if intent_data == null:
		text.text = ""
		text.modulate = Color.WHITE
		icon.texture = null
		return
	text.text = intent_data.base_text
	text.modulate = intent_data.text_color
	if intent_data.icon_uid != "":
		icon.texture = load(intent_data.icon_uid)
	else:
		icon.texture = null

func _on_mouse_entered() -> void:
	Events.tooltip_source_entered.emit(self, _build_tooltip_request())

func _on_mouse_exited() -> void:
	Events.tooltip_source_exited.emit(self)

func _build_tooltip_request() -> TooltipRequest:
	var request := TooltipRequest.new()
	request.anchor_control = self
	request.anchor_rect = get_global_rect()
	request.icon_uid = intent_data.icon_uid if intent_data != null else ""
	request.text_bbcode = intent_data.tooltip if intent_data != null else ""
	return request
