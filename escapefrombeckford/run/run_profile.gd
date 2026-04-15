# run_profile.gd

class_name RunProfile
extends RefCounted

enum StartMode {
	NEW_RUN,
	CONTINUE_RUN,
	LOAD_DEBUG_SLOT,
	TUTORIAL,
}

var start_mode: StartMode = StartMode.NEW_RUN
var has_soulbound_roster: bool = true
var player_profile_id: String = ""
var selected_starting_soul_uid: String = ""
var selected_signature_soul_serialized: Dictionary = {}
var seed: int = 0
var debug_slot_name: String = ""


func set_selected_signature_soul(card_data: CardData) -> void:
	selected_signature_soul_serialized = CardSnapshot.card_to_serialized_snapshot(card_data)


func instantiate_selected_signature_soul() -> CardData:
	if selected_signature_soul_serialized.is_empty():
		return null
	return CardSnapshot.instantiate_from_serialized_dict(selected_signature_soul_serialized)
