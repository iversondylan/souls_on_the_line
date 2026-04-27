class_name RewardButton extends Button

@export var reward_texture: Texture : set = set_reward_texture
@export var reward_text: String : set = set_reward_text
@export var reward_icon_modulate: Color = Color.WHITE : set = set_reward_icon_modulate

@onready var custom_icon: TextureRect = %CustomIcon
@onready var custom_text: Label = %CustomText

func set_reward_texture(new_texture: Texture) -> void:
	reward_texture = new_texture
	
	if !is_node_ready():
		await ready
	
	custom_icon.texture = reward_texture

func set_reward_icon_modulate(new_modulate: Color) -> void:
	reward_icon_modulate = new_modulate

	if !is_node_ready():
		await ready

	custom_icon.modulate = reward_icon_modulate

func set_reward_text(new_text: String) -> void:
	reward_text = new_text
	
	if !is_node_ready():
		await ready
	
	custom_text.text = reward_text
