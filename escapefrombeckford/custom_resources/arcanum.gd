class_name Arcanum extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}

@export var arcanum_name: String
@export var id: String
@export var type: Type
@export var starter_arcanum: bool = false
@export var icon: Texture
@export_multiline var tooltip_description: String
@export_multiline var flavor_text: String
@export_multiline var lore: String

func activate_arcanum(arcanum_display: ArcanumDisplay) -> void:
	pass

# This method should be implemented by event-based arcana
# that connect to the Events bus to make sure that they
# are disconnected when an arcanum is removed.
func deactivate_arcanum(arcanum_display: ArcanumDisplay) -> void:
	pass

func initialize_arcanum(arcanum_display: ArcanumDisplay) -> void:
	pass

func get_tooltip() -> String:
	return tooltip_description

##OH NO THIS SYSTEM IS AWFUL BECAUSE IT LOOPS OVER EVERY POSSIBLE PLAYER ARCANUM FOR EACH POSSIBLE ARCANUM, PROBABLY
## Looping occurs in arcana.gd
func can_appear_as_reward(player: PlayerData) -> bool:
	if starter_arcanum:
		return false
	return player.possible_arcana.get_ids().has(id)
