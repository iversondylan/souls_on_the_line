class_name EncounterHintPanel extends Control

const DEFAULT_PORTRAIT_PATH := "res://_assets/character_visuals/oswin_carrel/too_young_oswin_bdsf.png"

@export var visible_seconds: float = 2.4
@export var fade_seconds: float = 0.18

@onready var portrait: TextureRect = %Portrait
@onready var speaker_name_label: Label = %SpeakerName
@onready var hint_text_label: RichTextLabel = %HintText

var _hide_generation: int = 0
var _tween: Tween = null

func _ready() -> void:
	modulate = Color.TRANSPARENT
	hide()

func show_text(text_bbcode: String, speaker_name := "Oswin", portrait_path := DEFAULT_PORTRAIT_PATH) -> void:
	if text_bbcode.is_empty():
		return
	_hide_generation += 1
	var my_generation := _hide_generation
	if _tween != null:
		_tween.kill()
	speaker_name_label.text = speaker_name
	hint_text_label.clear()
	hint_text_label.append_text(text_bbcode)
	portrait.texture = load(portrait_path if !portrait_path.is_empty() else DEFAULT_PORTRAIT_PATH)
	show()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", Color.WHITE, fade_seconds)
	await get_tree().create_timer(visible_seconds, false).timeout
	if my_generation != _hide_generation:
		return
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate", Color.TRANSPARENT, fade_seconds)
	_tween.tween_callback(hide)
