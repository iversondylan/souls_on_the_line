class_name EncounterStep extends Resource

enum DeniedPresentation {
	HINT,
	DIALOGUE_INFO,
	DIALOGUE_BLOCKING,
}

@export var id: StringName = &""
@export var next_step_id: StringName = &""
@export var block_input_while_dialogue: bool = true
@export var player_turn_draw_amount_override: int = -1
@export var entry_actions: Array = []
@export var completion_conditions: Array = []
@export var triggers: Array = []
@export var capability_overrides: Resource
@export var on_complete_actions: Array = []

@export_group("Denied Feedback")
@export_multiline var denied_message_bbcode: String = ""
@export var denied_presentation: DeniedPresentation = DeniedPresentation.HINT
@export var denied_speaker_name: String = "Oswin"
@export var denied_confirm_text: String = "Continue"
@export var denied_portrait_path: String = "res://_assets/character_visuals/oswin_carrel/too_young_oswin_bdsf.png"
