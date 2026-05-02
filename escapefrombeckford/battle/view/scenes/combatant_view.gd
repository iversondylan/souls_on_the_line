# combatant_view.gd
#
# Contract (current as of your quarter-note beat refactor)
# ------------------------------------------------------------------------------
# - Director provides phase start + duration + presentation metadata.
# - Melee:
#   - WINDUP: one pose-load beat (can be reused across multi-strike chains)
#   - FOLLOWTHROUGH: exactly ONE strike per beat, uses StrikeFollowthroughOrder.strike_index
# - Ranged:
#   - WINDUP beats represent FIRE beats (one projectile per windup beat / per-strike slice)
#   - Projectiles own their own impact via tween callback (no external “impact” calls)
# - Receiving hit numbers/flinch happens when director calls play_received_hit_from_hitinfo()
#
# NOTE:
# - This file intentionally does NOT rely on BattleView projectile registries.
# - _strike_gen invalidates old async pulses/spawns when a new windup begins.
# ------------------------------------------------------------------------------

class_name CombatantView
extends Node2D


# ------------------------------------------------------------------------------
# Scene refs
# ------------------------------------------------------------------------------

@onready var character_art: Sprite2D = $ArtParent/CharacterArt
@onready var art_parent: Node2D = $ArtParent

@onready var camera_focus: Node2D = $CameraFocus
@onready var intent_container: IntentContainer = $IntentContainer
@onready var targeted_arrow: Sprite2D = $TargetedArrow
@onready var health_bar: HealthBar = $HealthBar
@onready var status_view_grid: StatusViewGrid = $StatusViewGrid
@onready var target_area: CombatantTargetArea = $TargetArea
@onready var area_left: CombatantAreaLeft = $AreaLeft
@onready var pending_turn_glow: Sprite2D = $PendingTurnGlow
@onready var combat_preview_overlay: CombatPreviewOverlay = $CombatPreviewOverlay

const DAMAGE_NUMBER_SCN_PATH := "uid://bubk456bw3da4"
const FOCUS_SOUND_KEY := &"focus_sound"
const CLEAR_FOCUS_SOUND_KEY := &"clear_focus_sound"
const WINDUP_SOUND_KEY := &"windup_sound"
const MELEE_IMPACT_SOUND_KEY := &"melee_impact_sound"
const FIRE_PROJECTILE_SOUND_KEY := &"fire_projectile_sound"
const FIREBALL_IMPACT_SOUND_KEY := &"fireball_impact_sound"
const STATUS_SOUND_KEY := &"status_sound"

const DEFAULT_FOCUS_SOUND := preload("uid://crxdrboqk438e")
const DEFAULT_CLEAR_FOCUS_SOUND := preload("uid://behqvr7ofgtw0")
const DEFAULT_WINDUP_SOUND := preload("uid://u6i36p7jadxm")
const DEFAULT_MELEE_IMPACT_SOUND := preload("uid://ddrxex8lotgxn")
const DEFAULT_FIRE_PROJECTILE_SOUND := preload("uid://20341tfvmh04")
const DEFAULT_FIREBALL_IMPACT_SOUND := preload("uid://c6myiupet7ros")
const DEFAULT_STATUS_SOUND := preload("uid://doh4nvpl4srwy")

# ------------------------------------------------------------------------------
# Core state
# ------------------------------------------------------------------------------

enum Type { ALLY, ENEMY, PLAYER }
enum TurnStatus { NONE, TURN_PENDING, TURN_ACTIVE }

var type: Type : set = _set_type
var mortality: CombatantState.Mortality = CombatantState.Mortality.MORTAL
var has_summon_reserve_card: bool = false
var display_name: String = ""
var cid: int = -1 : set = _set_cid
var group_index: int = -1 # 0 friendly, 1 enemy

var _status_catalog: StatusCatalog = null
var _spec: Dictionary = {}
var focus_sound: Sound = DEFAULT_FOCUS_SOUND
var clear_focus_sound: Sound = DEFAULT_CLEAR_FOCUS_SOUND
var windup_sound: Sound = DEFAULT_WINDUP_SOUND
var melee_impact_sound: Sound = DEFAULT_MELEE_IMPACT_SOUND
var fire_projectile_sound: Sound = DEFAULT_FIRE_PROJECTILE_SOUND
var fireball_impact_sound: Sound = DEFAULT_FIREBALL_IMPACT_SOUND
var status_sound: Sound = DEFAULT_STATUS_SOUND

var _height_px: int = 240
var health: int = 1
var max_health: int = 2
var is_alive: bool = true

var mana: int = 0
var max_mana: int = 0

var anchor_position: Vector2
var has_anchor_position: bool = false
var _root_motion_locked: bool = false
var _is_focus_active: bool = false
var _owns_focus_audio: bool = false

var tween_move: Tween
var tween_focus: Tween
var tween_strike: Tween
var tween_hit: Tween
var tween_misc: Tween

# Used to invalidate old async pulses/projectiles
var _strike_gen: int = 0

# Cached resting transform for art_parent
var _base_art_scale: Vector2 = Vector2.ONE
var _base_art_pos: Vector2 = Vector2.ZERO
var _base_cached: bool = false


func is_bound() -> bool:
	return int(mortality) == int(CombatantState.Mortality.BOUND)


func set_has_summon_reserve_card(new_value: bool) -> void:
	has_summon_reserve_card = new_value
	_refresh_health_bar_status_icons()


# ------------------------------------------------------------------------------
# Identity / setup
# ------------------------------------------------------------------------------

func _set_cid(new_cid: int) -> void:
	cid = new_cid
	if target_area:
		target_area.cid = cid
	if area_left:
		area_left.cid = cid


func _set_type(new_type: int) -> void:
	type = new_type as Type

	if type == Type.PLAYER:
		if !Events.player_targeted_arrow_visible.is_connected(show_targeted_arrow):
			Events.player_targeted_arrow_visible.connect(show_targeted_arrow)

	if type == Type.PLAYER or type == Type.ALLY:
		if !is_node_ready():
			await ready
		area_left.monitorable = true
		area_left.monitoring = true


func apply_spawn_spec(spec: Dictionary) -> void:
	_spec = spec.duplicate(true)
	_apply_visuals_from_spec()
	_apply_stats_from_spec()

func is_root_motion_locked() -> bool:
	return _root_motion_locked


func get_visual_height_px() -> int:
	return _height_px


func _apply_visuals_from_spec() -> void:
	var nm := String(_spec.get(Keys.COMBATANT_NAME, ""))
	if nm != "":
		display_name = nm
		_set_name_label(nm)

	var tint: Color = _spec.get(Keys.COLOR_TINT, Color.WHITE)
	character_art.modulate = tint

	var uid := String(_spec.get(Keys.ART_UID, ""))
	if uid == "":
		uid = String(_spec.get(Keys.PROTO_PATH, ""))

	var tex := load(uid) as Texture2D
	if tex != null:
		character_art.texture = tex

	var height := int(_spec.get(Keys.HEIGHT, 365))
	_height_px = height

	if character_art.texture != null:
		var scalar := float(height) / float(character_art.texture.get_height())
		character_art.scale = Vector2(scalar, scalar)

	character_art.position = Vector2(0, -height / 2.0)
	camera_focus.position = Vector2(0, -height / 1.5)
	intent_container.position = Vector2(0, -height + 20)
	combat_preview_overlay.position = Vector2(0, -height / 2.0 + 10)
	targeted_arrow.position = Vector2(0, -height)

	var faces_right := bool(_spec.get(Keys.ART_FACES_RIGHT, true))
	character_art.flip_h = faces_right != (get_parent() as GroupView).faces_right

	_cache_base_art_transform_if_needed()


func _apply_stats_from_spec() -> void:
	mortality = int(_spec.get(Keys.MORTALITY, CombatantState.Mortality.MORTAL)) as CombatantState.Mortality
	has_summon_reserve_card = bool(_spec.get(Keys.HAS_SUMMON_RESERVE_CARD, false))
	max_health = int(_spec.get(Keys.MAX_HEALTH, 0))
	health = int(_spec.get(Keys.HEALTH, 0))
	focus_sound = _resolve_sound_from_spec(FOCUS_SOUND_KEY, DEFAULT_FOCUS_SOUND)
	clear_focus_sound = _resolve_sound_from_spec(CLEAR_FOCUS_SOUND_KEY, DEFAULT_CLEAR_FOCUS_SOUND)
	windup_sound = _resolve_sound_from_spec(WINDUP_SOUND_KEY, DEFAULT_WINDUP_SOUND)
	melee_impact_sound = _resolve_sound_from_spec(MELEE_IMPACT_SOUND_KEY, DEFAULT_MELEE_IMPACT_SOUND)
	fire_projectile_sound = _resolve_sound_from_spec(FIRE_PROJECTILE_SOUND_KEY, DEFAULT_FIRE_PROJECTILE_SOUND)
	fireball_impact_sound = _resolve_sound_from_spec(FIREBALL_IMPACT_SOUND_KEY, DEFAULT_FIREBALL_IMPACT_SOUND)
	status_sound = _resolve_sound_from_spec(STATUS_SOUND_KEY, DEFAULT_STATUS_SOUND)
	if health_bar != null:
		health_bar.update_health_view(max_health, health)
	_refresh_health_bar_status_icons()


func _refresh_health_bar_status_icons() -> void:
	if health_bar != null:
		health_bar.update_status_icons(mortality, has_summon_reserve_card)


func _resolve_sound_from_spec(key: StringName, fallback: Sound) -> Sound:
	if _spec == null or !_spec.has(key):
		return fallback

	var value = _spec.get(key, null)
	if value is Sound:
		return value as Sound

	if value is String or value is StringName:
		var path := String(value)
		if path != "":
			var loaded := load(path) as Sound
			if loaded != null:
				return loaded

	return fallback


func _play_sound(sound: Sound, single := false, runtime_volume_db := 0.0, runtime_pitch := 0.0) -> void:
	if sound == null:
		return
	SFXPlayer.play(sound, single, runtime_volume_db, runtime_pitch)


# ------------------------------------------------------------------------------
# Hover / targeting
# ------------------------------------------------------------------------------

func _on_target_area_area_entered(area: Area2D) -> void:
	if area is not CardTargetSelectorArea:
		return

	var selector := area.card_target_selector as CardTargetSelector
	if selector == null:
		return
	show_targeted_arrow(selector.can_target_area(target_area))


func _on_target_area_area_exited(_area: Area2D) -> void:
	show_targeted_arrow(false)


func show_targeted_arrow(show_it: bool) -> void:
	if targeted_arrow != null:
		targeted_arrow.visible = show_it


func clear_combat_preview() -> void:
	if combat_preview_overlay != null:
		combat_preview_overlay.clear_preview()


func set_status_depiction_marker(marker_key: String, marker_kind: StringName, show_it: bool) -> void:
	if combat_preview_overlay != null:
		combat_preview_overlay.set_status_depiction_marker(marker_key, marker_kind, show_it)


func clear_status_depiction_marker_key(marker_key: String) -> void:
	if combat_preview_overlay != null:
		combat_preview_overlay.clear_status_depiction_marker_key(marker_key)


func clear_status_depiction_marker_prefix(marker_prefix: String) -> void:
	if combat_preview_overlay != null:
		combat_preview_overlay.clear_status_depiction_marker_prefix(marker_prefix)


func show_combat_preview_death() -> void:
	if combat_preview_overlay != null:
		combat_preview_overlay.show_death_preview()


func show_combat_preview_health(after_health: int, before_health: int) -> void:
	if combat_preview_overlay != null:
		combat_preview_overlay.show_health_preview(after_health, max_health, before_health)


func _on_target_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		if !is_alive:
			return
		Events.combatant_view_clicked.emit(self)


# ------------------------------------------------------------------------------
# Turn glow
# ------------------------------------------------------------------------------

func set_pending_turn_glow(status: TurnStatus) -> void:
	match status:
		TurnStatus.TURN_ACTIVE:
			pending_turn_glow.show()
			pending_turn_glow.modulate = Color(1.0, 0.65, 0.25)
		TurnStatus.TURN_PENDING:
			pending_turn_glow.show()
			pending_turn_glow.modulate = Color(0.45, 0.65, 1.0)
		TurnStatus.NONE:
			pending_turn_glow.hide()


# ------------------------------------------------------------------------------
# Focus
# ------------------------------------------------------------------------------

func on_focus(order: FocusOrder) -> void:
	var involved := (cid == order.attacker_id)
	if !involved:
		for tid in order.target_ids:
			if cid == int(tid):
				involved = true
				break

	_is_focus_active = true
	_owns_focus_audio = (cid == int(order.attacker_id))
	if _owns_focus_audio:
		_play_sound(focus_sound)

	if tween_focus:
		tween_focus.kill()

	var target_scale := Vector2.ONE * (order.scale_involved if involved else order.scale_uninvolved)
	var target_dim := 1.0 if involved else order.dim_uninvolved

	var dur := maxf(order.duration * 0.75, 0.01)
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", target_scale, dur)
	tween_focus.parallel().tween_property(self, "modulate", Color(target_dim, target_dim, target_dim, 1.0), dur)


func clear_focus(duration: float) -> void:
	if _owns_focus_audio:
		_play_sound(clear_focus_sound)
	_owns_focus_audio = false

	if _root_motion_locked:
		_is_focus_active = false
		if tween_focus:
			tween_focus.kill()
			tween_focus = null
		return

	_is_focus_active = false

	if tween_focus:
		tween_focus.kill()
		tween_focus = null

	var dur := maxf(duration * 0.75, 0.01)
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", Vector2.ONE, dur)
	tween_focus.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), dur)
	tween_focus.finished.connect(func() -> void:
		tween_focus = null
	, CONNECT_ONE_SHOT)

	# Focus owns root motion during the turn, so package-driven relayouts may only
	# update the stored anchor. When focus clears, reconcile back to that anchor.
	if has_anchor_position and is_alive:
		if tween_move:
			tween_move.kill()
			tween_move = null
		if position.distance_to(anchor_position) <= 0.5:
			position = anchor_position
		else:
			tween_move = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween_move.tween_property(self, "position", anchor_position, maxf(dur, 0.12))
			tween_move.finished.connect(func() -> void:
				tween_move = null
			, CONNECT_ONE_SHOT)


# ------------------------------------------------------------------------------
# Group movement
# ------------------------------------------------------------------------------

func set_anchor_position(new_position: Vector2, ctx: GroupLayoutOrder) -> void:
	anchor_position = new_position

	# Once death has begun, root position is frozen.
	if _root_motion_locked:
		has_anchor_position = true
		return

	if tween_move:
		tween_move.kill()
		tween_move = null

	# Dead / dying units do not participate in layout.
	if !is_alive:
		has_anchor_position = true
		return

	var should_animate := false
	if ctx != null:
		should_animate = bool(ctx.animate_to_position)

	# First placement should snap, never tween.
	if !has_anchor_position:
		position = anchor_position
		has_anchor_position = true
		return

	if should_animate:
		# Avoid tiny corrective tweens that can read as jitter.
		if position.distance_to(anchor_position) <= 0.5:
			position = anchor_position
			has_anchor_position = true
			return

		tween_move = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_move.tween_property(self, "position", anchor_position, 0.12)
		tween_move.finished.connect(func() -> void:
			tween_move = null
		, CONNECT_ONE_SHOT)
	else:
		position = anchor_position

	has_anchor_position = true




# ------------------------------------------------------------------------------
# Attack entry points
# ------------------------------------------------------------------------------

func play_presentation_order(order: PresentationOrder, battle_view: BattleView) -> void:
	if order == null:
		return

	match int(order.kind):
		PresentationOrder.Kind.MELEE_WINDUP:
			_play_melee_windup_from_order(order as MeleeWindupPresentationOrder)

		PresentationOrder.Kind.MELEE_STRIKE:
			_play_melee_strike_from_order(order as MeleeStrikePresentationOrder)

		PresentationOrder.Kind.RANGED_WINDUP:
			_play_ranged_windup_from_order(order as RangedWindupPresentationOrder)

		PresentationOrder.Kind.RANGED_FIRE:
			_play_ranged_fire_from_order(order as RangedFirePresentationOrder, battle_view)

		PresentationOrder.Kind.RANGED_CLEAVE:
			_play_ranged_cleave_from_order(order as RangedFirePresentationOrder, battle_view)

		PresentationOrder.Kind.IMPACT:
			_play_impact_from_order(order as ImpactPresentationOrder)

		PresentationOrder.Kind.REMOVAL:
			_play_removal_from_order(order)

		PresentationOrder.Kind.STATUS_WINDUP:
			_play_status_windup_from_order(order as StatusWindupPresentationOrder)

		PresentationOrder.Kind.STATUS_POP:
			_play_status_pop_from_order(order as StatusPopPresentationOrder)

		_:
			pass

func _play_melee_windup_from_order(order: MeleeWindupPresentationOrder) -> void:
	if order == null:
		return
	_play_sound(windup_sound)
	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	#var base_pos := _get_base_art_pos()

	#var drift := float(order.drift_x)
	#var g := get_parent()
	#if g is GroupView and !(g as GroupView).faces_right:
		#drift = -drift

	# Loaded pose
	var windup_scale := Vector2(base_scale.x * 0.88, base_scale.y * 1.16)
	#var windup_pos := base_pos + Vector2(drift, -4)

	var dur := maxf(order.visual_sec, 0.01)
	var snap_t := maxf(dur * 0.42, 0.04)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", windup_scale, snap_t)
	#tween_strike.parallel().tween_property(art_parent, "position", windup_pos, snap_t)
	#var o := StrikeWindupOrder.new()
	#o.duration = order.visual_sec if order.visual_sec > 0.0 else 0.20
	#o.attacker_id = int(order.actor_id)
	#o.target_ids = order.target_ids
	#o.attack_mode = Attack.Mode.MELEE
	#o.strike_count = int(order.strike_count)
	#o.total_hit_count = int(order.total_hit_count)
#
	#play_strike_windup(o, null)


func _play_melee_strike_from_order(order: MeleeStrikePresentationOrder) -> void:
	if order == null:
		return

	var o := StrikeFollowthroughOrder.new()
	o.duration = order.visual_sec if order.visual_sec > 0.0 else 0.22
	o.attacker_id = int(order.actor_id)
	o.target_ids = order.target_ids
	o.attack_mode = Attack.Mode.MELEE
	o.strike_count = 1
	o.strike_index = int(order.strike_index)
	o.total_hit_count = int(order.total_hit_count)
	o.has_lethal_hit = bool(order.has_lethal)
	o.chained_from_previous = bool(order.chained_from_previous)
	o.origin_strike_index = int(order.origin_strike_index)
	o.chain_source_target_id = int(order.chain_source_target_id)

	play_strike_followthrough(o, null)


func _play_ranged_windup_from_order(order: RangedWindupPresentationOrder) -> void:
	if order == null:
		return
	_play_sound(windup_sound)
	#if !is_instance_valid(self) or gen != _strike_gen:
		#return
	
	if tween_strike:
		tween_strike.kill()
	
	#_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	#var base_pos := _get_base_art_pos()
	
	var load_scale := Vector2(base_scale.x * 0.95, base_scale.y * 1.05)
	#var load_pos := base_pos + Vector2(0, -2)
	
	var dur := maxf(order.visual_sec, 0.01)
	
	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", load_scale, dur)
	#tween_strike.parallel().tween_property(art_parent, "position", load_pos, dur)
	#_strike_gen += 1
	#var gen := _strike_gen
#
	##var dur := order.visual_sec if order.visual_sec > 0.0 else 0.15
	#_play_ranged_windup_pose_async(dur, gen)


func _play_ranged_fire_from_order(order: RangedFirePresentationOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return
	
	var gen := _strike_gen
	
	if tween_strike:
		tween_strike.kill()
	
	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	#var base_pos := _get_base_art_pos()

	var peak_scale := Vector2(base_scale.x * 0.97, base_scale.y * 1.03)
	#var peak_pos := base_pos + Vector2(0, -3)
	var up_t : float = order.visual_sec*0.25
	var down_t : float = order.visual_sec*0.25
	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", peak_scale, maxf(up_t, 0.01))
	#tween_strike.parallel().tween_property(art_parent, "position", peak_pos, maxf(up_t, 0.01))
	
	tween_strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_strike.tween_property(art_parent, "scale", base_scale, maxf(down_t, 0.01))
	#tween_strike.parallel().tween_property(art_parent, "position", base_pos, maxf(down_t, 0.01))
	
	var o := StrikeWindupOrder.new()
	o.duration = order.visual_sec if order.visual_sec > 0.0 else 0.18
	o.attacker_id = int(order.actor_id)
	o.target_ids = order.target_ids
	o.attack_mode = Attack.Mode.RANGED
	o.strike_count = 1
	o.strike_index = int(order.strike_index)
	o.projectile_scene_path = order.projectile_scene_path
	o.chained_from_previous = bool(order.chained_from_previous)
	o.origin_strike_index = int(order.origin_strike_index)
	o.chain_source_target_id = int(order.chain_source_target_id)
	o.has_chain_continuation = bool(order.has_chain_continuation)

	#_play_ranged_fire_pulse(o, gen)
	if !bool(order.suppress_projectile_spawn):
		_spawn_projectile_for_ranged_strike(o, battle_view, gen)


func _play_ranged_cleave_from_order(order: RangedFirePresentationOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return

	var o := StrikeWindupOrder.new()
	var clock := battle_view.clock if battle_view != null else _get_battle_clock()
	var continuation_duration := 0.5 * clock.seconds_per_quarter() if clock != null else 0.18
	o.duration = continuation_duration
	o.attacker_id = int(order.actor_id)
	o.target_ids = order.target_ids
	o.attack_mode = Attack.Mode.RANGED
	o.strike_count = 1
	o.strike_index = int(order.strike_index)
	o.projectile_scene_path = order.projectile_scene_path
	o.chained_from_previous = true
	o.origin_strike_index = int(order.origin_strike_index)
	o.chain_source_target_id = int(order.chain_source_target_id)
	o.has_chain_continuation = false

	if !bool(order.suppress_projectile_spawn):
		_spawn_projectile_for_ranged_strike(o, battle_view, _strike_gen)


func play_projectile_from_ranged_order(
	order: RangedFirePresentationOrder,
	battle_view: BattleView,
	projectile_scene_path: String
) -> void:
	if order == null or battle_view == null or projectile_scene_path.is_empty():
		return

	var o := StrikeWindupOrder.new()
	if int(order.kind) == int(PresentationOrder.Kind.RANGED_CLEAVE):
		var clock := battle_view.clock if battle_view != null else _get_battle_clock()
		o.duration = 0.5 * clock.seconds_per_quarter() if clock != null else 0.18
	else:
		o.duration = order.visual_sec if order.visual_sec > 0.0 else 0.18
	o.attacker_id = int(order.actor_id)
	o.target_ids = order.target_ids
	o.attack_mode = Attack.Mode.RANGED
	o.strike_count = 1
	o.strike_index = int(order.strike_index)
	o.projectile_scene_path = projectile_scene_path
	o.chained_from_previous = bool(order.chained_from_previous)
	o.origin_strike_index = int(order.origin_strike_index)
	o.chain_source_target_id = int(order.chain_source_target_id)
	o.has_chain_continuation = bool(order.has_chain_continuation)

	_spawn_projectile_for_ranged_strike(o, battle_view, _strike_gen)


func _play_impact_from_order(order: ImpactPresentationOrder) -> void:
	if order == null:
		return

	var h := HitPresentationInfo.new()
	h.target_id = int(order.target_id)
	h.amount = int(order.amount)
	h.after_health = int(order.after_health)
	h.was_lethal = bool(order.was_lethal)

	var dur := order.visual_sec if order.visual_sec > 0.0 else 0.18
	play_received_hit_from_hitinfo(h, dur)


func _play_removal_from_order(order) -> void:
	if order == null:
		return
	play_removal_followthrough(
		int(order.removal_type),
		order.visual_sec if order.visual_sec > 0.0 else 0.24
	)


func _play_status_windup_from_order(order: StatusWindupPresentationOrder) -> void:
	if order == null:
		return

	if cid == int(order.actor_id):
		_play_sound(windup_sound)
		_play_status_source_windup(order)

	for tid in order.target_ids:
		if cid == int(tid):
			show_targeted(true)
			_play_status_target_windup(order)
			break


func _play_status_pop_from_order(order: StatusPopPresentationOrder) -> void:
	if order == null:
		return

	if cid == int(order.source_id):
		_play_sound(status_sound)
		_play_status_source_pop(order)

	if cid == int(order.target_id):
		show_targeted(false)
		_play_status_target_pop(order)


func _play_status_source_windup(order: StatusWindupPresentationOrder) -> void:
	if order == null:
		return

	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()
	var mode := StringName(order.presentation_mode)
	var compact := mode == &"compact_followup"
	var nonattack := mode == &"effect_sequence_nonattack"
	var scale_mult := 1.03 if compact else (1.045 if nonattack else 1.06)
	var lift := -1.5 if compact else (-2.2 if nonattack else -3.0)
	var dur := maxf(order.visual_sec, 0.01)

	tween_strike = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", base_scale * scale_mult, dur)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos + Vector2(0, lift), dur)


func _play_status_target_windup(order: StatusWindupPresentationOrder) -> void:
	if order == null:
		return

	if tween_misc:
		tween_misc.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var mode := StringName(order.presentation_mode)
	var compact := mode == &"compact_followup"
	var nonattack := mode == &"effect_sequence_nonattack"
	var scale_mult := 1.02 if compact else (1.03 if nonattack else 1.04)
	var dur := maxf(order.visual_sec, 0.01)

	tween_misc = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_misc.tween_property(art_parent, "scale", base_scale * scale_mult, dur)


func _play_status_source_pop(order: StatusPopPresentationOrder) -> void:
	if order == null:
		return

	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()
	var mode := StringName(order.presentation_mode)
	var compact := mode == &"compact_followup"
	var nonattack := mode == &"effect_sequence_nonattack"
	var peak_scale := base_scale * (1.04 if compact else (1.06 if nonattack else 1.08))
	var peak_pos := base_pos + Vector2(0, -2.0 if compact else (-3.0 if nonattack else -4.0))
	var dur := maxf(order.visual_sec, 0.01)
	var up_t := maxf(dur * 0.45, 0.02)
	var down_t := maxf(dur * 0.55, 0.02)

	tween_strike = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", peak_scale, up_t)
	tween_strike.parallel().tween_property(art_parent, "position", peak_pos, up_t)
	tween_strike.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_strike.tween_property(art_parent, "scale", base_scale, down_t)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, down_t)


func _play_status_target_pop(order: StatusPopPresentationOrder) -> void:
	if order == null:
		return

	if tween_misc:
		tween_misc.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var mode := StringName(order.presentation_mode)
	var compact := mode == &"compact_followup"
	var nonattack := mode == &"effect_sequence_nonattack"
	var pulse_scale := base_scale * (1.05 if compact else (1.06 if nonattack else 1.08))
	var dur := maxf(order.visual_sec, 0.01)
	var up_t := maxf(dur * 0.40, 0.02)
	var down_t := maxf(dur * 0.60, 0.02)

	tween_misc = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_misc.tween_property(art_parent, "scale", pulse_scale, up_t)
	tween_misc.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween_misc.tween_property(art_parent, "scale", base_scale, down_t)

func _play_ranged_windup_pose_async(duration: float, gen: int) -> void:
	if !is_instance_valid(self) or gen != _strike_gen:
		return

	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var load_scale := Vector2(base_scale.x * 0.95, base_scale.y * 1.05)
	var load_pos := base_pos + Vector2(0, -2)

	var dur := maxf(duration, 0.01)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", load_scale, dur)
	tween_strike.parallel().tween_property(art_parent, "position", load_pos, dur)

func play_summon_windup(duration: float) -> void:
	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var g := get_parent()
	var drift := 10.0
	if g is GroupView and !(g as GroupView).faces_right:
		drift = -drift

	var windup_scale := Vector2(base_scale.x * 0.90, base_scale.y * 1.14)
	var windup_pos := base_pos + Vector2(drift, -4)

	var dur := maxf(duration, 0.01)
	var snap_t := maxf(dur * 0.42, 0.04)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", windup_scale, snap_t)
	tween_strike.parallel().tween_property(art_parent, "position", windup_pos, snap_t)
	if dur > snap_t:
		tween_strike.tween_interval(dur - snap_t)


func play_summon_pop_scale(duration := 0.10) -> void:
	if character_art == null:
		return

	var final_scale := character_art.scale
	character_art.scale = Vector2.ZERO

	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_art, "scale", final_scale, maxf(duration, 0.01))


func play_strike_windup(order: StrikeWindupOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return

	_strike_gen += 1
	var gen := _strike_gen
	_play_sound(windup_sound)

	if int(order.attack_mode) == int(Attack.Mode.RANGED):
		# One projectile per windup beat / per-strike slice.
		_play_ranged_fire_pulse(order, gen)
		_spawn_projectile_for_ranged_strike(order, battle_view, gen)
		return

	_play_melee_windup(order)


func play_strike_followthrough(order: StrikeFollowthroughOrder, _battle_view: BattleView) -> void:
	if order == null:
		return

	# ranged followthrough has no attacker body motion
	if int(order.attack_mode) == int(Attack.Mode.RANGED):
		return

	if bool(order.chained_from_previous):
		return

	_play_melee_followthrough_per_strike(order)


# Director calls this on the beat it wants hit reactions (usually the strike followthrough beat)
func play_received_hit_from_hitinfo(h: HitPresentationInfo, phase_duration: float) -> void:
	if h == null or !is_alive:
		return
	_apply_received_hit(h, maxf(phase_duration, 0.01))


func clear_strike_pose(duration: float) -> void:
	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var dur := maxf(duration, 0.01)
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "scale", base_scale, dur)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, dur)


# ------------------------------------------------------------------------------
# Melee feel
# ------------------------------------------------------------------------------

func _play_melee_windup(order: StrikeWindupOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var drift := float(order.drift_x)
	var g := get_parent()
	if g is GroupView and !(g as GroupView).faces_right:
		drift = -drift

	# Loaded pose
	var windup_scale := Vector2(base_scale.x * 0.88, base_scale.y * 1.16)
	var windup_pos := base_pos + Vector2(drift, -4)

	var dur := maxf(order.duration, 0.01)
	var snap_t := maxf(dur * 0.42, 0.04)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", windup_scale, snap_t)
	tween_strike.parallel().tween_property(art_parent, "position", windup_pos, snap_t)
	if dur > snap_t:
		tween_strike.tween_interval(dur - snap_t)


func _play_melee_followthrough_per_strike(order: StrikeFollowthroughOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	_play_sound(melee_impact_sound)

	var dur := maxf(order.duration, 0.01)
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	# strike_index drives chaining feel (2nd+ strike starts “compressed”)
	var chain_bias := 0.0
	if int(order.strike_index) > 0:
		chain_bias = clampf(float(order.strike_index), 0.0, 3.0) * 0.35

	var start_scale := base_scale
	var start_pos := base_pos
	if chain_bias > 0.0:
		start_scale = base_scale * Vector2(1.04 + 0.01 * chain_bias, 0.92 - 0.01 * chain_bias)
		start_pos = base_pos + Vector2(0, 1.0 * chain_bias)

	var snap_scale := Vector2(
		base_scale.x * (order.x_scale + 0.04 * chain_bias),
		base_scale.y * (order.y_scale - 0.02 * chain_bias)
	)

	var shake := float(order.shake_px)
	shake += 1.25 * float(maxi(1, order.total_hit_count) - 1)
	if order.has_lethal_hit:
		shake += 2.0

	# respect facing
	var g := get_parent()
	if g is GroupView and !(g as GroupView).faces_right:
		shake = -shake

	var snap_t := maxf(dur * float(order.snap_ratio), 0.04)
	var recover_t := maxf(dur - snap_t, 0.06)

	art_parent.scale = start_scale
	art_parent.position = start_pos

	tween_strike = create_tween()
	tween_strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", snap_scale, snap_t)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos + Vector2(shake, 0), snap_t)

	tween_strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "scale", base_scale, recover_t)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, recover_t)


# ------------------------------------------------------------------------------
# Ranged fire beat (single-shot per beat)
# ------------------------------------------------------------------------------

func _play_ranged_fire_pulse(_order: StrikeWindupOrder, gen: int) -> void:
	# Simple pulse that starts immediately at beat start.
	_ranged_pulse_async(0.0, 0.12, 0.10, gen)


func _get_battle_clock() -> BattleClock:
	var group_view := get_parent()
	if group_view is GroupView:
		var battle_view := (group_view as GroupView).get_parent()
		if battle_view is BattleView:
			return (battle_view as BattleView).clock
	return null


func _ranged_pulse_async(delay_sec: float, up_t: float, down_t: float, gen: int) -> void:
	var clock := _get_battle_clock()
	if delay_sec > 0.0:
		if clock != null:
			await clock.wait_seconds(delay_sec)
		else:
			push_warning("CombatantView._ranged_pulse_async(): missing battle clock; skipping pulse delay")
	if !is_instance_valid(self) or gen != _strike_gen:
		return

	if tween_strike:
		tween_strike.kill()

	_cache_base_art_transform_if_needed()
	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var peak_scale := Vector2(base_scale.x * 0.97, base_scale.y * 1.03)
	var peak_pos := base_pos + Vector2(0, -3)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", peak_scale, maxf(up_t, 0.01))
	tween_strike.parallel().tween_property(art_parent, "position", peak_pos, maxf(up_t, 0.01))

	tween_strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_strike.tween_property(art_parent, "scale", base_scale, maxf(down_t, 0.01))
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, maxf(down_t, 0.01))


func _spawn_projectile_for_ranged_strike(order: StrikeWindupOrder, battle_view: BattleView, gen: int) -> void:
	# Spawn immediately; travel time == beat duration (keeps musical alignment).
	# Targets should already be per-strike from director (slice.get_target_ids()).
	_spawn_projectile_async(order, battle_view, gen, 0.0, maxf(order.duration, 0.01), order.target_ids)


func _spawn_projectile_async(
	order: StrikeWindupOrder,
	battle_view: BattleView,
	gen: int,
	spawn_t: float,
	travel_t: float,
	target_ids: Array[int]
) -> void:
	var clock := battle_view.clock if battle_view != null else _get_battle_clock()
	if spawn_t > 0.0:
		if clock != null:
			await clock.wait_seconds(spawn_t)
		else:
			push_warning("CombatantView._spawn_projectile_async(): missing battle clock; skipping projectile spawn delay")

	if !is_instance_valid(self) or gen != _strike_gen:
		return

	var proj_path := String(order.projectile_scene_path)
	if proj_path == "":
		proj_path = "uid://bxmhi3urqmpfh"

	var projectile_key := battle_view.make_projectile_key(
		int(order.attacker_id),
		int(order.origin_strike_index if order.origin_strike_index >= 0 else order.strike_index)
	)
	var projectile: Node2D = null
	var start_pos := _get_projectile_origin_global()

	if bool(order.chained_from_previous):
		projectile = battle_view.take_projectile(projectile_key)
		if projectile != null and is_instance_valid(projectile):
			start_pos = projectile.global_position
		else:
			projectile = null
		if projectile == null and int(order.chain_source_target_id) > 0:
			var chain_source := battle_view.get_combatant(int(order.chain_source_target_id))
			if chain_source != null and is_instance_valid(chain_source):
				start_pos = chain_source.get_projectile_origin_global()
			else:
				start_pos = battle_view.get_mean_target_position_global([int(order.chain_source_target_id)], start_pos)

	if projectile == null:
		var scene: PackedScene = FxLibrary.get_scene(proj_path)
		if scene == null:
			push_warning("Missing projectile scene: %s" % proj_path)
			return
		projectile = scene.instantiate() as Node2D
		if projectile == null:
			return
		battle_view.add_child(projectile)
		if !bool(order.chained_from_previous):
			_play_sound(fire_projectile_sound)

	var end_pos := battle_view.get_mean_target_position_global(target_ids, start_pos)
	end_pos.y = start_pos.y

	var group := get_parent()
	if group is GroupView and !(group as GroupView).faces_right and !bool(order.chained_from_previous):
		projectile.scale.x *= -1

	projectile.global_position = start_pos

	var t := projectile.create_tween().set_trans(Tween.TRANS_LINEAR)
	t.tween_property(projectile, "global_position", end_pos, maxf(travel_t, 0.01))

	# Projectile owns its impact + lifetime.
	t.tween_callback(func():
		if !is_instance_valid(projectile):
			return
		if bool(order.has_chain_continuation):
			battle_view.put_projectile(projectile_key, projectile)
			return
		_play_sound(fireball_impact_sound)
		projectile.play_impact()
	)


func _get_projectile_origin_global() -> Vector2:
	var height := float(_spec.get(Keys.HEIGHT, 270))
	var offset := Vector2(0, -(height * 0.67))
	return global_position + offset


func get_projectile_origin_global() -> Vector2:
	return _get_projectile_origin_global()


# ------------------------------------------------------------------------------
# Receiving hits / death
# ------------------------------------------------------------------------------

func _apply_received_hit(h: HitPresentationInfo, _phase_duration: float) -> void:
	play_hit()
	set_health(h.after_health, h.was_lethal)
	pop_damage_number(h.amount)


func play_removal_windup(order) -> void:
	if order == null:
		return

	var dur := maxf(order.duration, 0.01)
	if int(order.removal_type) == int(Removal.Type.FADE):
		if character_art == null:
			return
		if tween_misc:
			tween_misc.kill()
		tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween_misc.tween_property(character_art, "modulate:a", 0.0, dur)
		tween_misc.finished.connect(func() -> void:
			tween_misc = null
		, CONNECT_ONE_SHOT)
		return

	play_removal_followthrough(int(order.removal_type), dur)


func play_removal_followthrough(removal_type: int, duration: float) -> void:
	if int(removal_type) == int(Removal.Type.FADE):
		if character_art == null:
			return
		if tween_misc:
			tween_misc.kill()
			tween_misc = null
		var fade_dur := maxf(duration, 0.01)
		tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tween_misc.tween_property(character_art, "modulate:a", 0.0, fade_dur)
		tween_misc.finished.connect(func() -> void:
			tween_misc = null
		, CONNECT_ONE_SHOT)
		return

	# Prevent duplicate death-start ownership fights.
	if _root_motion_locked:
		return

	_root_motion_locked = true
	_is_focus_active = false
	is_alive = false

	if tween_move:
		tween_move.kill()
		tween_move = null

	if tween_focus:
		tween_focus.kill()
		tween_focus = null

	if tween_hit:
		tween_hit.kill()
		tween_hit = null

	if tween_strike:
		tween_strike.kill()
		tween_strike = null

	if tween_misc:
		tween_misc.kill()
		tween_misc = null

	_cache_base_art_transform_if_needed()

	# Freeze the root exactly where it is right now.
	anchor_position = position
	has_anchor_position = true

	if intent_container != null:
		intent_container.visible = false
	if health_bar != null:
		health_bar.visible = false
	if status_view_grid != null:
		status_view_grid.visible = false
	if pending_turn_glow != null:
		pending_turn_glow.hide()
	if targeted_arrow != null:
		targeted_arrow.hide()

	var dur := maxf(duration, 0.01)
	var base_pos := _get_base_art_pos()
	var base_scale := _get_base_art_scale()

	var slump := Vector2(0, 10.0)
	var shrink_scale := base_scale * 0.96
	var to_col := Color(0, 0, 0, 1.0)

	# Snap root in case any tween left fractional drift.
	position = anchor_position

	tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_misc.tween_property(character_art, "modulate", to_col, dur)
	tween_misc.parallel().tween_property(art_parent, "position", base_pos + slump, dur)
	tween_misc.parallel().tween_property(art_parent, "scale", shrink_scale, dur)
	tween_misc.finished.connect(func() -> void:
		tween_misc = null
	, CONNECT_ONE_SHOT)


# ------------------------------------------------------------------------------
# Catalog / cached base transform helpers
# ------------------------------------------------------------------------------

func bind_status_catalog(catalog: StatusCatalog) -> void:
	_status_catalog = catalog
	if status_view_grid != null:
		status_view_grid.bind(cid, _status_catalog)


func _cache_base_art_transform_if_needed() -> void:
	if _base_cached:
		return
	_base_cached = true
	_base_art_scale = art_parent.scale
	_base_art_pos = art_parent.position


func _get_base_art_scale() -> Vector2:
	_cache_base_art_transform_if_needed()
	return _base_art_scale


func _get_base_art_pos() -> Vector2:
	_cache_base_art_transform_if_needed()
	return _base_art_pos


# ------------------------------------------------------------------------------
# Misc stubs / small FX
# ------------------------------------------------------------------------------

func _set_name_label(_nm: String) -> void:
	pass


func play_summon_fx() -> void:
	pass


func play_targeting() -> void:
	pass


func show_targeted(_is_targeted: bool) -> void:
	pass


func set_fade_mark(_on: bool) -> void:
	pass


func play_attack_react() -> void:
	pass


func add_status_icon(_status_id: StringName) -> void:
	pass


func remove_status_icon(_status_id: StringName) -> void:
	pass


func play_hit() -> void:
	if tween_hit:
		tween_hit.kill()

	_cache_base_art_transform_if_needed()
	var base_pos := _get_base_art_pos()
	var base_scale := _get_base_art_scale()

	var kick := Vector2(2, 0)
	tween_hit = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_hit.tween_property(art_parent, "position", base_pos + kick, 0.05)
	tween_hit.tween_property(art_parent, "position", base_pos, 0.08).set_ease(Tween.EASE_IN_OUT)
	tween_hit.parallel().tween_property(art_parent, "scale", base_scale * Vector2(1.02, 0.98), 0.05)
	tween_hit.tween_property(art_parent, "scale", base_scale, 0.08)


func play_heal_fx() -> void:
	pass


func pop_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	var scn: PackedScene = FxLibrary.get_scene(DAMAGE_NUMBER_SCN_PATH)
	if scn == null:
		push_warning("Missing DamageNumber scene at %s" % DAMAGE_NUMBER_SCN_PATH)
		return
	var dn := scn.instantiate() as BattleFloatingNumber
	if dn == null:
		return
	add_child(dn)
	dn.animate_and_vanish(amount, _height_px)


func pop_heal_number(_amount: int) -> void:
	pass


func set_health(new_health: int, was_lethal: bool = false) -> void:
	health = clampi(new_health, 0, max_health)
	if health_bar != null:
		health_bar.update_health_view(max_health, health)
		_refresh_health_bar_status_icons()
	if was_lethal:
		pass
