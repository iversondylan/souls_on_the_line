# fx_library.gd

extends Node

const FX_RIPPLE := &"ripple"
const FX_LIGHT_RADIAL := &"light_radial"
const FX_AIR_BUBBLE := &"air_bubble"
const FX_LIQUID_GLASS := &"liquid_glass"
const FX_LIQUID_GLASS_SQUIRM := &"liquid_glass_squirm"
const FX_SMOKE_POOF := &"smoke_poof"
const FX_RESONANCE_SPIKE_RIPPLES := &"resonance_spike_ripples"

const NAMED_SCENE_PATHS := {
	FX_RIPPLE: "res://VFX/shader_rects/ripple.tscn",
	FX_LIGHT_RADIAL: "res://VFX/shader_rects/light_radial.tscn",
	FX_AIR_BUBBLE: "res://VFX/shader_rects/air_bubble.tscn",
	FX_LIQUID_GLASS: "res://VFX/shader_rects/liquid_glass.tscn",
	FX_LIQUID_GLASS_SQUIRM: "res://VFX/shader_rects/liquid_glass_squirm.tscn",
	FX_SMOKE_POOF: "res://VFX/shader_rects/smoke_poof.tscn",
	FX_RESONANCE_SPIKE_RIPPLES: "res://VFX/shader_rects/resonance_spike_ripples.tscn",
}

var _scenes: Dictionary = {} # String -> PackedScene

# Optional: warm-up list (paths you know you’ll use often)
@export var warm_paths: PackedStringArray = [
	"uid://bxmhi3urqmpfh",
	"uid://b88mfp6wnsbs7",
	"res://VFX/shader_rects/ripple.tscn",
	"res://VFX/shader_rects/light_radial.tscn",
	"res://VFX/shader_rects/air_bubble.tscn",
	"res://VFX/shader_rects/liquid_glass.tscn",
	"res://VFX/shader_rects/liquid_glass_squirm.tscn",
	"res://VFX/shader_rects/smoke_poof.tscn",
	"res://VFX/shader_rects/resonance_spike_ripples.tscn",
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


func get_named_scene(fx_id: StringName) -> PackedScene:
	var path := String(NAMED_SCENE_PATHS.get(fx_id, ""))
	if path.is_empty():
		push_warning("FxLibrary: unknown fx id %s" % String(fx_id))
		return null
	return get_scene(path)
