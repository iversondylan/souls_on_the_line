class_name Campfire extends Control

const CARD_SELECTION_OVERLAY := preload("res://run/ui/card_selection_overlay.tscn")
const MENU_CARD := preload("uid://d4g7iin5x7648")

var run_state: RunState
var profile_data: ProfileData
var run_deck: RunDeck

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attune_button: Button = %AttuneButton

var _slot_overlay: ColorRect
var _confirm_dialog: ConfirmationDialog
var _pending_slot_index: int = -1
var _pending_slot_uid: String = ""
var _pending_attuned_card: CardData


func _ready() -> void:
	if profile_data == null:
		profile_data = SaveService.load_or_create_profile()
	if run_deck == null and run_state != null:
		run_deck = run_state.run_deck
	_build_slot_overlay()
	_build_confirm_dialog()
	_refresh_attune_button()


func _refresh_attune_button() -> void:
	attune_button.disabled = profile_data == null \
		or profile_data.soul_recess_state == null \
		or run_deck == null \
		or run_deck.card_collection == null


func _build_slot_overlay() -> void:
	_slot_overlay = ColorRect.new()
	_slot_overlay.color = Color(0.076, 0.06, 0.12, 0.94)
	_slot_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_overlay.visible = false
	add_child(_slot_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_slot_overlay.add_child(center)

	var box := VBoxContainer.new()
	box.theme_override_constants.separation = 20
	center.add_child(box)

	var title := Label.new()
	title.text = "Choose an Attuned Soul"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var slots := HBoxContainer.new()
	slots.name = "Slots"
	slots.alignment = BoxContainer.ALIGNMENT_CENTER
	slots.theme_override_constants.separation = 20
	box.add_child(slots)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_hide_slot_overlay)
	box.add_child(cancel_button)


func _build_confirm_dialog() -> void:
	_confirm_dialog = ConfirmationDialog.new()
	_confirm_dialog.dialog_text = "Are you sure? This will replace the currently attuned soul."
	_confirm_dialog.get_ok_button().text = "Attune"
	_confirm_dialog.confirmed.connect(_confirm_attunement)
	add_child(_confirm_dialog)


func _on_rest_button_pressed() -> void:
	if run_state == null or run_state.player_run_state == null:
		return
	var ctx := HealContext.new(1, 1, 0, 0.3, 0)
	run_state.player_run_state.heal(ctx)
	animation_player.play("fade_out")


func _on_attune_button_pressed() -> void:
	if profile_data == null or profile_data.soul_recess_state == null:
		return
	_show_slot_overlay()


func _show_slot_overlay() -> void:
	if _slot_overlay == null:
		return
	var slots := _slot_overlay.get_node("CenterContainer/VBoxContainer/Slots") as HBoxContainer
	for child in slots.get_children():
		child.queue_free()

	var recess := profile_data.soul_recess_state
	var visible_slots := mini(recess.attuned_souls.size(), maxi(int(recess.unlocked_slot_count), 0))
	for slot_index in range(visible_slots):
		var snapshot := recess.get_attuned_soul_snapshot_at(slot_index)
		var card_data := snapshot.instantiate_card() if snapshot != null else null
		if card_data == null:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(210, 320)
		button.pressed.connect(_open_attunement_candidates.bind(slot_index, String(card_data.uid)))
		slots.add_child(button)

		var menu_card := MENU_CARD.instantiate() as MenuCard
		button.add_child(menu_card)
		menu_card.set_anchors_preset(Control.PRESET_FULL_RECT)
		menu_card.offset_left = 0.0
		menu_card.offset_top = 0.0
		menu_card.offset_right = 0.0
		menu_card.offset_bottom = 0.0
		menu_card.set_card_data(card_data)
		_set_mouse_passthrough(menu_card)

	_slot_overlay.visible = true


func _hide_slot_overlay() -> void:
	if _slot_overlay != null:
		_slot_overlay.visible = false


func _open_attunement_candidates(slot_index: int, slot_uid: String) -> void:
	_pending_slot_index = slot_index
	_pending_slot_uid = slot_uid

	var overlay = CARD_SELECTION_OVERLAY.instantiate()
	add_child(overlay)
	overlay.selection_confirmed.connect(_on_attunement_candidate_selected)
	overlay.configure(
		_get_attunement_candidates(),
		"Choose a SoulBound Card",
		"Attune",
		"Cancel"
	)


func _get_attunement_candidates() -> Array[CardData]:
	var candidates: Array[CardData] = []
	if run_deck == null or run_deck.card_collection == null:
		return candidates
	for card_data in run_deck.card_collection.cards:
		if card_data == null:
			continue
		if int(card_data.card_type) != int(CardData.CardType.SOULBOUND):
			continue
		if bool(card_data.starter_card):
			continue
		candidates.append(card_data)
		if candidates.size() >= 5:
			break
	return candidates


func _on_attunement_candidate_selected(card_data: CardData) -> void:
	_pending_attuned_card = card_data
	if _confirm_dialog != null:
		_confirm_dialog.popup_centered()


func _confirm_attunement() -> void:
	if _pending_attuned_card == null or profile_data == null or profile_data.soul_recess_state == null:
		return

	var snapshot := CardSnapshot.from_card(_pending_attuned_card)
	if snapshot == null or snapshot.card == null:
		return
	snapshot.card.ensure_uid()

	profile_data.soul_recess_state.set_attuned_soul_snapshot(_pending_slot_index, snapshot)
	if String(profile_data.soul_recess_state.selected_starting_soul_uid) == _pending_slot_uid:
		profile_data.soul_recess_state.selected_starting_soul_uid = String(snapshot.card.uid)
	SaveService.save_profile(profile_data)

	_pending_slot_index = -1
	_pending_slot_uid = ""
	_pending_attuned_card = null
	_hide_slot_overlay()


func _set_mouse_passthrough(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_set_mouse_passthrough(child)


func _on_fade_out_finished() -> void:
	Events.campfire_exited.emit()
