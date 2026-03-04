# combatant_view.gd
class_name CombatantView
extends Node2D

@onready var character_art: Sprite2D = $CharacterArt
@onready var camera_focus: Node2D = $CameraFocus
@onready var intent_container: IntentContainer = $IntentContainer
@onready var targeted_arrow: Sprite2D = $TargetedArrow
@onready var health_bar: HealthBar = $HealthBar
var display_name: String = ""
var cid: int = 0
var character_art_uid: String

var _spec: Dictionary = {}

var health : int = 1
var max_health: int = 2
var mana: int = 3
var max_mana: int = 3
#var _assets: BattleAssetCache = null

#func bind_assets(cache: BattleAssetCache) -> void:
	#_assets = cache

var tween_move: Tween
var tween_strike: Tween
var tween_hit: Tween
var tween_focus: Tween
var tween_misc: Tween

func apply_spawn_spec(spec: Dictionary) -> void:
	_spec = spec.duplicate(true)
	_apply_visuals_from_spec()
	_apply_stats_from_spec()

func _apply_visuals_from_spec() -> void:
	var nm := String(_spec.get(Keys.COMBATANT_NAME, ""))
	if nm != "":
		display_name = nm
		_set_name_label(nm)
	
	var tint: Color = _spec.get(Keys.COLOR_TINT, Color.WHITE)
	character_art.modulate = tint
	
	var uid := String(_spec.get(Keys.ART_UID, ""))
	if uid == "":
		uid = String(_spec.get(Keys.PROTO_PATH, "")) # fallback if you want
	var tex := load(uid) as Texture2D #_assets.get_texture(uid) if _assets != null else (load(uid) as Texture2D)
	if tex != null:
		character_art.texture = tex
	
	var height := int(_spec.get(Keys.HEIGHT, 365))
	if character_art.texture != null:
		var scalar := float(height) / float(character_art.texture.get_height())
		character_art.scale = Vector2(scalar, scalar)
	
	character_art.position = Vector2(0, -height / 2.0)
	camera_focus.position = Vector2(0, -height / 1.5)
	intent_container.position = Vector2(0, -height + 20)
	targeted_arrow.position = Vector2(0, -height)
	
	# facing
	var faces_right := bool(_spec.get(Keys.ART_FACES_RIGHT, true))
	character_art.flip_h = faces_right != (get_parent() as GroupView).faces_right#!faces_right if (get_parent() as GroupView).faces_right else faces_right

func _apply_stats_from_spec() -> void:
	# Use spec values for initial UI.
	# Later, you can add dedicated events for health changes etc.
	max_health = int(_spec.get(Keys.MAX_HEALTH, 0))
	health = int(_spec.get(Keys.HEALTH, 0))
	# health_bar.update_health_from_numbers(hp, max_hp) # adapt to your API
	health_bar.update_health_view(max_health, health)

func on_focus(order: FocusOrder) -> void:
	pass

func clear_focus(duration: float) -> void:
	pass

func _set_name_label(_nm: String) -> void:
	# optional: wire to your label if exists
	pass

func play_summon_fx() -> void:
	# TODO: puff + pop-in
	pass

func play_targeting() -> void:
	# TODO: subtle pulse/aim animation
	pass

func show_targeted(_is_targeted: bool) -> void:
	# TODO: toggle targeted arrow
	pass

func play_hit() -> void:
	# TODO: flash + shake
	pass

func pop_damage_number(_amount: int) -> void:
	# TODO: floating text
	pass

func play_attack_react() -> void:
	# optional: attacker recoil anim
	pass

func add_status_icon(_status_id: StringName) -> void:
	# TODO: update grid
	pass

func remove_status_icon(_status_id: StringName) -> void:
	# TODO: update grid
	pass

func set_health(new_health: int, was_lethal: bool = false) -> void:
	health = clampi(new_health, 0, max_health)
	health_bar.update_health_view(max_health, health)
	if was_lethal:
		# later: death animation
		pass
	

func _set_character_art(_uid: String) -> void:
	character_art.texture = load(_uid) as Texture
