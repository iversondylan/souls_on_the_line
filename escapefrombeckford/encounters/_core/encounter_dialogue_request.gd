class_name EncounterDialogueRequest extends RefCounted

enum Mode {
	BLOCKING,
	INFO,
}

var dialogue_id: StringName = &""
var mode: int = Mode.BLOCKING
var speaker_name: String = "Oswin"
var portrait_path: String = "res://_assets/character_visuals/oswin_carrel/too_young_oswin_bdsf.png"
var text_bbcode: String = ""
var confirm_text: String = "Continue"
var anchor_rect: Rect2 = Rect2()
var step_id: StringName = &""
