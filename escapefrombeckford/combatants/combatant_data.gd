# combatant_data.gd

class_name CombatantData extends Resource

@export_group("Visuals")
@export var name: String = "error"
@export_multiline var description: String
@export var character_art_uid: String
@export var portrait_art_uid: String
@export var facing_right: bool = true
@export var height: int = 365
@export var color_tint: Color = Color.WHITE

@export_group("Gameplay Data")
@export var max_health: int = 10
@export var ap: int = 3
@export var max_mana: int = 3
@export var ai: NPCAIProfile

func load_character_art() -> Texture2D:
	if character_art_uid.is_empty():
		return null
	return load(character_art_uid) as Texture2D

func load_portrait_art() -> Texture2D:
	var uid := portrait_art_uid if !portrait_art_uid.is_empty() else character_art_uid
	if uid.is_empty():
		return null
	return load(uid) as Texture2D
