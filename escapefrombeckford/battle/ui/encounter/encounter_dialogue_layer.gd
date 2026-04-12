class_name EncounterDialogueLayer extends Control

const DEFAULT_PORTRAIT_PATH := "res://_assets/character_visuals/oswin_carrel/too_young_oswin_bdsf.png"

@onready var dialogue_panel = %EncounterDialoguePanel
@onready var hint_panel = %EncounterHintPanel

var director: EncounterDirector = null

func bind_director(encounter_director: EncounterDirector) -> void:
	if director != null:
		if director.dialogue_requested.is_connected(_on_dialogue_requested):
			director.dialogue_requested.disconnect(_on_dialogue_requested)
		if director.gate_denied.is_connected(_on_gate_denied):
			director.gate_denied.disconnect(_on_gate_denied)
	director = encounter_director
	if director == null:
		return
	if !dialogue_panel.confirmed.is_connected(_on_dialogue_confirmed):
		dialogue_panel.confirmed.connect(_on_dialogue_confirmed)
	director.dialogue_requested.connect(_on_dialogue_requested)
	director.gate_denied.connect(_on_gate_denied)

func _on_dialogue_requested(request: EncounterDialogueRequest) -> void:
	if request == null:
		return
	if int(request.mode) == int(EncounterDialogueRequest.Mode.BLOCKING):
		dialogue_panel.show_request(request)
		return
	hint_panel.show_text(request.text_bbcode, request.speaker_name, request.portrait_path)

func _on_gate_denied(result: GateResult) -> void:
	if result == null or result.player_message.is_empty():
		return
	hint_panel.show_text(result.player_message, "Oswin", DEFAULT_PORTRAIT_PATH)

func _on_dialogue_confirmed(dialogue_id: StringName) -> void:
	dialogue_panel.hide_panel()
	if director != null:
		director.acknowledge_dialogue(dialogue_id)
