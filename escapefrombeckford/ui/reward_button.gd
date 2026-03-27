class_name RewardButton extends Button

@export var reward_texture: Texture : set = set_reward_texture
@export var reward_text: String : set = set_reward_text

@onready var custom_icon: TextureRect = %CustomIcon
@onready var custom_text: Label = %CustomText

func set_reward_texture(new_texture: Texture) -> void:
	reward_texture = new_texture
	
	if !is_node_ready():
		await ready
	
	custom_icon.texture = reward_texture

func set_reward_text(new_text: String) -> void:
	reward_text = new_text
	
	if !is_node_ready():
		await ready
	
	custom_text.text = reward_text

func _on_pressed() -> void:
	queue_free()
