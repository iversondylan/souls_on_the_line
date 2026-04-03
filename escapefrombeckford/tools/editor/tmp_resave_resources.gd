extends SceneTree

const PATHS := [
	"res://statuses/burning_ambition.tres",
	"res://cards/enchantments/BurningAmbition/burning_ambition_action.tres",
	"res://cards/enchantments/BurningAmbition/burning_ambition.tres",
	"res://statuses/_core/status_catalog.tres",
	"res://character_profiles/Cole/cole_basic_deck.tres",
	"res://character_profiles/Cole/cole_draftable_cards.tres",
]


func _init() -> void:
	for path in PATHS:
		var resource := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null:
			push_error("Failed to load %s" % path)
			quit(1)
			return
		resource.resource_path = path
		var err := ResourceSaver.save(resource, path)
		if err != OK:
			push_error("Failed to save %s err=%d" % [path, err])
			quit(1)
			return
		print("resaved %s" % path)

	quit()
