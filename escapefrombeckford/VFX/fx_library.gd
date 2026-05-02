# fx_library.gd

extends Node

const FX_RIPPLE := &"ripple"
const FX_LIGHT_RADIAL := &"light_radial"
const FX_AIR_BUBBLE := &"air_bubble"
const FX_LIQUID_GLASS := &"liquid_glass"
const FX_LIQUID_GLASS_SQUIRM := &"liquid_glass_squirm"
const FX_SMOKE_POOF := &"smoke_poof"
const FX_RESONANCE_SPIKE_RIPPLES := &"resonance_spike_ripples"
const FX_BLUE_SLASH_V1_1 := &"blue_slash_v1_1"
const FX_BLUE_SLASH_V1_2 := &"blue_slash_v1_2"
const FX_PARTICLES_BASIC_V1_A := &"particles_basic_v1_a"
const FX_CIRCLE_CUTOUT_V2_REVERSE := &"circle_cutout_v2_reverse"
const FX_IMPACT_SHINE_V1_REVERSE := &"impact_shine_v1_reverse"
const FX_WIND_GROUND_ALPHAP5 := &"wind_ground_alphap5"
const FX_WIND_GROUND_ALPHAP5_A := &"wind_ground_alphap5_a"
const FX_WIND_GROUND_ALPHAP5_B := &"wind_ground_alphap5_b"
const FX_EXPLOSION_BOMB_V1 := &"explosion_bomb_v1"
const FX_EXPLOSION_BOMB_V2 := &"explosion_bomb_v2"
const FX_EXPLOSION_BOMB_V3 := &"explosion_bomb_v3"
const FX_EXPLOSION_BOMB_V4 := &"explosion_bomb_v4"
const FX_EXPLOSION_BOMB_V5 := &"explosion_bomb_v5"
const FX_EXPLOSION_BOMB_V6 := &"explosion_bomb_v6"
const FX_EXPLOSION_BOMB_V7 := &"explosion_bomb_v7"
const FX_EXPLOSION_BOMB_V8 := &"explosion_bomb_v8"
const FX_EXPLOSION_FIRE := &"explosion_fire"
const FX_EXPLOSION_LIGHTNING := &"explosion_lightning"
const FX_HEALING_V5_A := &"healing_v5_a"
const FX_IMPACT_FIRE_LV1 := &"impact_fire_lv1"
const FX_IMPACT_FIRE_LV2 := &"impact_fire_lv2"
const FX_IMPACT_FIRE_LV3 := &"impact_fire_lv3"
const FX_IMPACT_HIT_LV1 := &"impact_hit_lv1"
const FX_IMPACT_HIT_LV2 := &"impact_hit_lv2"
const FX_IMPACT_HIT_LV3 := &"impact_hit_lv3"
const FX_IMPACT_HOT_V1 := &"impact_hot_v1"
const FX_IMPACT_HOT_V2 := &"impact_hot_v2"
const FX_IMPACT_HOT_V3 := &"impact_hot_v3"
const FX_IMPACT_HOT_V4 := &"impact_hot_v4"
const FX_IMPACT_HOT_V5 := &"impact_hot_v5"
const FX_IMPACT_HOT_V6 := &"impact_hot_v6"
const FX_IMPACT_HOT_V7 := &"impact_hot_v7"
const FX_IMPACT_HOT_V7_NO_SHARDS := &"impact_hot_v7_no_shards"
const FX_IMPACT_HOT_V8 := &"impact_hot_v8"
const FX_IMPACT_HOT_V8_NO_SHARDS := &"impact_hot_v8_no_shards"
const FX_IMPACT_HOT_V9 := &"impact_hot_v9"
const FX_IMPACT_SHOCKWAVE_V2 := &"impact_shockwave_v2"

const NAMED_SCENE_PATHS := {
	FX_RIPPLE: "res://VFX/shader_rects/ripple.tscn",
	FX_LIGHT_RADIAL: "res://VFX/shader_rects/light_radial.tscn",
	FX_AIR_BUBBLE: "res://VFX/shader_rects/air_bubble.tscn",
	FX_LIQUID_GLASS: "res://VFX/shader_rects/liquid_glass.tscn",
	FX_LIQUID_GLASS_SQUIRM: "res://VFX/shader_rects/liquid_glass_squirm.tscn",
	FX_SMOKE_POOF: "res://VFX/shader_rects/smoke_poof.tscn",
	FX_RESONANCE_SPIKE_RIPPLES: "res://VFX/shader_rects/resonance_spike_ripples.tscn",
	FX_BLUE_SLASH_V1_1: "res://VFX/melee/blue_slash_v1_1.tscn",
	FX_BLUE_SLASH_V1_2: "res://VFX/melee/blue_slash_v1_2.tscn",
	FX_PARTICLES_BASIC_V1_A: "res://VFX/impacts/particles_basic_v1_A.tscn",
	FX_CIRCLE_CUTOUT_V2_REVERSE: "res://VFX/chargups/circle_cutout_v2_reverse.tscn",
	FX_IMPACT_SHINE_V1_REVERSE: "res://VFX/chargups/impact_shine_v1_reverse.tscn",
	FX_WIND_GROUND_ALPHAP5: "res://VFX/floor/wind_ground_alphap5.tscn",
	FX_WIND_GROUND_ALPHAP5_A: "res://VFX/floor/wind_ground_alphap5_a.tscn",
	FX_WIND_GROUND_ALPHAP5_B: "res://VFX/floor/wind_ground_alphap5_b.tscn",
	FX_EXPLOSION_BOMB_V1: "res://VFX/impacts/explosion_bomb_v1.tscn",
	FX_EXPLOSION_BOMB_V2: "res://VFX/impacts/explosion_bomb_v2.tscn",
	FX_EXPLOSION_BOMB_V3: "res://VFX/impacts/explosion_bomb_v3.tscn",
	FX_EXPLOSION_BOMB_V4: "res://VFX/impacts/explosion_bomb_v4.tscn",
	FX_EXPLOSION_BOMB_V5: "res://VFX/impacts/explosion_bomb_v5.tscn",
	FX_EXPLOSION_BOMB_V6: "res://VFX/impacts/explosion_bomb_v6.tscn",
	FX_EXPLOSION_BOMB_V7: "res://VFX/impacts/explosion_bomb_v7.tscn",
	FX_EXPLOSION_BOMB_V8: "res://VFX/impacts/explosion_bomb_v8.tscn",
	FX_EXPLOSION_FIRE: "res://VFX/impacts/explosion_fire.tscn",
	FX_EXPLOSION_LIGHTNING: "res://VFX/impacts/explosion_lightning.tscn",
	FX_HEALING_V5_A: "res://VFX/impacts/healing_v5_a.tscn",
	FX_IMPACT_FIRE_LV1: "res://VFX/impacts/impact_fire_lv1.tscn",
	FX_IMPACT_FIRE_LV2: "res://VFX/impacts/impact_fire_lv2.tscn",
	FX_IMPACT_FIRE_LV3: "res://VFX/impacts/impact_fire_lv3.tscn",
	FX_IMPACT_HIT_LV1: "res://VFX/impacts/impact_hit_lv1.tscn",
	FX_IMPACT_HIT_LV2: "res://VFX/impacts/impact_hit_lv2.tscn",
	FX_IMPACT_HIT_LV3: "res://VFX/impacts/impact_hit_lv3.tscn",
	FX_IMPACT_HOT_V1: "res://VFX/impacts/impact_hot_v1.tscn",
	FX_IMPACT_HOT_V2: "res://VFX/impacts/impact_hot_v2.tscn",
	FX_IMPACT_HOT_V3: "res://VFX/impacts/impact_hot_v3.tscn",
	FX_IMPACT_HOT_V4: "res://VFX/impacts/impact_hot_v4.tscn",
	FX_IMPACT_HOT_V5: "res://VFX/impacts/impact_hot_v5.tscn",
	FX_IMPACT_HOT_V6: "res://VFX/impacts/impact_hot_v6.tscn",
	FX_IMPACT_HOT_V7: "res://VFX/impacts/impact_hot_v7.tscn",
	FX_IMPACT_HOT_V7_NO_SHARDS: "res://VFX/impacts/impact_hot_v7_no_shards.tscn",
	FX_IMPACT_HOT_V8: "res://VFX/impacts/impact_hot_v8.tscn",
	FX_IMPACT_HOT_V8_NO_SHARDS: "res://VFX/impacts/impact_hot_v8_no_shards.tscn",
	FX_IMPACT_HOT_V9: "res://VFX/impacts/impact_hot_v9.tscn",
	FX_IMPACT_SHOCKWAVE_V2: "res://VFX/impacts/impact_shockwave_v2.tscn",
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
	"res://VFX/melee/blue_slash_v1_1.tscn",
	"res://VFX/melee/blue_slash_v1_2.tscn",
	"res://VFX/impacts/particles_basic_v1_A.tscn",
	"res://VFX/chargups/circle_cutout_v2_reverse.tscn",
	"res://VFX/chargups/impact_shine_v1_reverse.tscn",
	"res://VFX/floor/wind_ground_alphap5.tscn",
	"res://VFX/floor/wind_ground_alphap5_a.tscn",
	"res://VFX/floor/wind_ground_alphap5_b.tscn",
	"res://VFX/impacts/explosion_bomb_v1.tscn",
	"res://VFX/impacts/explosion_bomb_v2.tscn",
	"res://VFX/impacts/explosion_bomb_v3.tscn",
	"res://VFX/impacts/explosion_bomb_v4.tscn",
	"res://VFX/impacts/explosion_bomb_v5.tscn",
	"res://VFX/impacts/explosion_bomb_v6.tscn",
	"res://VFX/impacts/explosion_bomb_v7.tscn",
	"res://VFX/impacts/explosion_bomb_v8.tscn",
	"res://VFX/impacts/explosion_fire.tscn",
	"res://VFX/impacts/explosion_lightning.tscn",
	"res://VFX/impacts/healing_v5_a.tscn",
	"res://VFX/impacts/impact_fire_lv1.tscn",
	"res://VFX/impacts/impact_fire_lv2.tscn",
	"res://VFX/impacts/impact_fire_lv3.tscn",
	"res://VFX/impacts/impact_hit_lv1.tscn",
	"res://VFX/impacts/impact_hit_lv2.tscn",
	"res://VFX/impacts/impact_hit_lv3.tscn",
	"res://VFX/impacts/impact_hot_v1.tscn",
	"res://VFX/impacts/impact_hot_v2.tscn",
	"res://VFX/impacts/impact_hot_v3.tscn",
	"res://VFX/impacts/impact_hot_v4.tscn",
	"res://VFX/impacts/impact_hot_v5.tscn",
	"res://VFX/impacts/impact_hot_v6.tscn",
	"res://VFX/impacts/impact_hot_v7.tscn",
	"res://VFX/impacts/impact_hot_v7_no_shards.tscn",
	"res://VFX/impacts/impact_hot_v8.tscn",
	"res://VFX/impacts/impact_hot_v8_no_shards.tscn",
	"res://VFX/impacts/impact_hot_v9.tscn",
	"res://VFX/impacts/impact_shockwave_v2.tscn",
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
