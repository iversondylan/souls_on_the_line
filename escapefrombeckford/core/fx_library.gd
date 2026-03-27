# fx_library.gd

extends Node

var _scenes: Dictionary = {} # String -> PackedScene

# Optional: warm-up list (paths you know you’ll use often)
@export var warm_paths: PackedStringArray = [
	"res://VFX/projectiles/fireball/fireball.tscn",
	"res://battle/ui/damage_number.tscn"
]

func _ready() -> void:
	for p in warm_paths:
		get_scene(p)

func get_scene(path: String) -> PackedScene:
	#print("fx_library.gd get_scene() path: ", path)
	if path == "":
		return null
	if _scenes.has(path):
		return _scenes[path]
	var s := load(path) as PackedScene
	if s == null:
		push_warning("ProjectileLibrary: failed to load PackedScene at %s" % path)
		return null
	_scenes[path] = s
	return s
