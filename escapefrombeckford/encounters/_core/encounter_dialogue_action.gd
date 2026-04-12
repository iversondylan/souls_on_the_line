class_name EncounterDialogueAction extends EncounterAction

enum DialogueMode {
	BLOCKING,
	INFO,
}

@export var dialogue_id: StringName = &""
@export var mode: DialogueMode = DialogueMode.BLOCKING
@export var speaker_name: String = "Oswin"
@export var portrait_path: String = "res://_assets/character_visuals/oswin_carrel/too_young_oswin_bdsf.png"
@export_multiline var text_bbcode: String = ""
@export var confirm_text: String = "Continue"

func execute(ctx: EncounterRuleContext) -> void:
	if ctx == null or ctx.director == null or text_bbcode.is_empty():
		return
	var request: EncounterDialogueRequest = EncounterDialogueRequest.new()
	request.dialogue_id = dialogue_id if dialogue_id != &"" else StringName("%s:%s" % [String(ctx.get_current_step_id()), str(get_instance_id())])
	request.mode = EncounterDialogueRequest.Mode.BLOCKING if int(mode) == int(DialogueMode.BLOCKING) else EncounterDialogueRequest.Mode.INFO
	request.speaker_name = speaker_name
	request.portrait_path = portrait_path
	request.text_bbcode = text_bbcode
	request.confirm_text = confirm_text
	request.step_id = ctx.get_current_step_id()
	ctx.director.queue_dialogue(request)
