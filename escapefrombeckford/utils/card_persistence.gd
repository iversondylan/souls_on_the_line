# card_persistence.gd

class_name CardPersistence
extends RefCounted

static func card_dir() -> String:
	return "user://cards"

static func card_path(uid: String) -> String:
	return "%s/%s.tres" % [card_dir(), uid]

static func ensure_dir_exists() -> void:
	DirAccess.make_dir_recursive_absolute(card_dir())

static func save_card(card: CardData) -> bool:
	if card == null:
		return false
	card.ensure_uid()
	ensure_dir_exists()

	# Ensure this instance is fully self-contained when saved:
	# We want actions saved inside the card file, not pointing at editor assets
	# unless you explicitly want that.
	_make_subresources_local(card)

	var path := card_path(card.uid)
	var err := ResourceSaver.save(card, path)
	if err != OK:
		push_warning("CardPersistence.save_card failed err=%s path=%s" % [err, path])
		return false
	return true

static func load_card(uid: String) -> CardData:
	var path := card_path(uid)
	if !FileAccess.file_exists(path):
		return null
	var res := ResourceLoader.load(path)
	return res as CardData

static func _make_subresources_local(card: CardData) -> void:
	# Make sure actions are stored as subresources in the saved .tres
	# so mutated actions persist with the card.
	if card.actions == null:
		return
	for i in range(card.actions.size()):
		var a := card.actions[i]
		if a == null:
			continue
		# If the action has its own nested resources, you may need to recurse later.
		a.resource_local_to_scene = true
	card.resource_local_to_scene = true
