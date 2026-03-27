# player_catalog.gd

class_name PlayerCatalog extends Resource

@export var profiles: Array[PlayerData] = []

var by_id: Dictionary = {}


func build_index() -> void:
	by_id.clear()
	for profile: PlayerData in profiles:
		if profile == null:
			continue
		var id := String(profile.profile_id)
		assert(!id.is_empty(), "PlayerData missing profile_id: %s" % profile.resource_path)
		assert(!by_id.has(id), "Duplicate player profile id: %s" % id)
		by_id[id] = profile


func get_profile(profile_id: String) -> PlayerData:
	return by_id.get(profile_id, null)


func get_default_profile() -> PlayerData:
	for profile: PlayerData in profiles:
		if profile != null:
			return profile
	return null
