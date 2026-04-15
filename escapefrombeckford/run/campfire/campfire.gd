class_name Campfire extends Control

const CARD_SELECTION_OVERLAY := preload("res://run/ui/card_selection_overlay.tscn")

var run_state: RunState
var profile_data: ProfileData
var run_deck: RunDeck

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var attune_button: Button = %AttuneButton
@onready var slot_overlay = %SlotOverlay

var _confirm_dialog: ConfirmationDialog
var _pending_slot_index: int = -1
var _pending_slot_uid: String = ""
var _pending_attuned_card: CardData


func configure(new_run_state: RunState, new_profile_data: ProfileData, new_run_deck: RunDeck) -> void:
	run_state = new_run_state
	profile_data = new_profile_data
	run_deck = new_run_deck if new_run_deck != null else (run_state.run_deck if run_state != null else null)
	if is_node_ready():
		_refresh_attune_button()


func _ready() -> void:
	if profile_data == null:
		profile_data = SaveService.load_or_create_profile()
	if run_deck == null and run_state != null:
		run_deck = run_state.run_deck
	if slot_overlay != null:
		slot_overlay.slot_selected.connect(_on_slot_overlay_selected)
		slot_overlay.canceled.connect(_on_slot_overlay_canceled)
	_build_confirm_dialog()
	_refresh_attune_button()


func _refresh_attune_button() -> void:
	attune_button.disabled = profile_data == null \
		or profile_data.soul_recess_state == null \
		or run_deck == null \
		or run_deck.card_collection == null


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
	if slot_overlay == null or profile_data == null or profile_data.soul_recess_state == null:
		return
	slot_overlay.show_slots(profile_data.soul_recess_state)


func _hide_slot_overlay() -> void:
	if slot_overlay != null:
		slot_overlay.hide_overlay()


func _on_slot_overlay_selected(slot_index: int, slot_uid: String) -> void:
	_open_attunement_candidates(slot_index, slot_uid)


func _on_slot_overlay_canceled() -> void:
	pass


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

func _on_fade_out_finished() -> void:
	Events.campfire_exited.emit()
