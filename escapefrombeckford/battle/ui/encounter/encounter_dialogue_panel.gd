class_name EncounterDialoguePanel extends Control

signal confirmed(dialogue_id: StringName)

const DEFAULT_PORTRAIT_PATH := "res://_assets/character_visuals/oswin_carrel/too_young_oswin_bdsf.png"

@onready var portrait: TextureRect = %Portrait
@onready var speaker_name_label: Label = %SpeakerName
@onready var dialogue_text_label: RichTextLabel = %DialogueText
@onready var confirm_button: Button = %ConfirmButton

var _current_dialogue_id: StringName = &""

func _ready() -> void:
	hide()
	confirm_button.pressed.connect(_on_confirm_button_pressed)

func show_request(request) -> void:
	if request == null:
		return
	_current_dialogue_id = request.dialogue_id
	speaker_name_label.text = request.speaker_name
	dialogue_text_label.clear()
	dialogue_text_label.append_text(request.text_bbcode)
	confirm_button.text = request.confirm_text if !request.confirm_text.is_empty() else "Continue"
	portrait.texture = load(request.portrait_path if !request.portrait_path.is_empty() else DEFAULT_PORTRAIT_PATH)
	show()

func hide_panel() -> void:
	_current_dialogue_id = &""
	hide()

func _on_confirm_button_pressed() -> void:
	confirmed.emit(_current_dialogue_id)
