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

const DAMAGE_NUMBER_SCN_PATH := "res://scenes/ui/damage_number.tscn"

# ------------------------------------------------------------------------------
# Core state
# ------------------------------------------------------------------------------

enum Type { ALLY, ENEMY, PLAYER }
enum Mortality { MORTAL, SOULBOUND, DEPLETE }
enum TurnStatus { NONE, TURN_PENDING, TURN_ACTIVE }

var type: Type : set = _set_type
var mortality: Mortality = Mortality.MORTAL
var display_name: String = ""
var cid: int = -1 : set = _set_cid
var group_index: int = -1 # 0 friendly, 1 enemy

var _status_catalog: StatusCatalog = null
var _spec: Dictionary = {}

var _height_px: int = 240
var health: int = 1
var max_health: int = 2
var is_alive: bool = true

var mana: int = 0
var max_mana: int = 0

var anchor_position: Vector2
var has_anchor_position: bool = false

var _is_focus_active: bool = false

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


func is_soulbound() -> bool:
	return int(mortality) == int(Mortality.SOULBOUND)


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
	type = new_type

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
	targeted_arrow.position = Vector2(0, -height)

	var faces_right := bool(_spec.get(Keys.ART_FACES_RIGHT, true))
	character_art.flip_h = faces_right != (get_parent() as GroupView).faces_right

	_cache_base_art_transform_if_needed()


func _apply_stats_from_spec() -> void:
	mortality = int(_spec.get(Keys.MORTALITY, CombatantView.Mortality.MORTAL))
	max_health = int(_spec.get(Keys.MAX_HEALTH, 0))
	health = int(_spec.get(Keys.HEALTH, 0))
	if health_bar != null:
		health_bar.update_health_view(max_health, health)


# ------------------------------------------------------------------------------
# Hover / targeting
# ------------------------------------------------------------------------------

func _on_target_area_area_entered(area: Area2D) -> void:
	if area is not CardTargetSelectorArea:
		return

	match area.card_target_selector.current_card.card_data.target_type:
		CardData.TargetType.ALLY_OR_SELF:
			if type == Type.ALLY or type == Type.PLAYER:
				show_targeted_arrow(true)
		CardData.TargetType.ALLY:
			if type == Type.ALLY:
				show_targeted_arrow(true)
		CardData.TargetType.SINGLE_ENEMY:
			if type == Type.ENEMY:
				show_targeted_arrow(true)


func _on_target_area_area_exited(_area: Area2D) -> void:
	show_targeted_arrow(false)


func show_targeted_arrow(show_it: bool) -> void:
	if targeted_arrow != null:
		targeted_arrow.visible = show_it


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
	_is_focus_active = true

	var involved := (cid == order.attacker_id)
	if !involved:
		for tid in order.target_ids:
			if cid == int(tid):
				involved = true
				break

	if tween_focus:
		tween_focus.kill()

	var target_scale := Vector2.ONE * (order.scale_involved if involved else order.scale_uninvolved)
	var target_dim := 1.0 if involved else order.dim_uninvolved

	var drift := 0.0
	if involved:
		var sign := 1.0 if (get_parent() as GroupView).faces_right else -1.0
		drift = sign * order.drift_involved

	var dur := maxf(order.duration * 0.75, 0.01)
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", target_scale, dur)
	tween_focus.parallel().tween_property(self, "position", Vector2(anchor_position.x + drift, 0), dur)
	tween_focus.parallel().tween_property(self, "modulate", Color(target_dim, target_dim, target_dim, 1.0), dur)


func clear_focus(duration: float) -> void:
	_is_focus_active = false

	if tween_focus:
		tween_focus.kill()
	if tween_move:
		tween_move.kill()

	var dur := maxf(duration * 0.75, 0.01)
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", Vector2.ONE, dur)
	tween_focus.parallel().tween_property(self, "position", anchor_position, dur)
	tween_focus.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), dur)


# ------------------------------------------------------------------------------
# Group movement
# ------------------------------------------------------------------------------

func set_anchor_position(_position: Vector2, ctx: GroupLayoutOrder) -> void:
	anchor_position = _position

	if _is_focus_active:
		has_anchor_position = true
		return

	if ctx.animate_to_position and has_anchor_position:
		if tween_move:
			tween_move.kill()
		tween_move = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween_move.tween_property(self, "position", anchor_position, 0.12)
	else:
		if tween_move:
			tween_move.kill()
		position = anchor_position

	has_anchor_position = true


# ------------------------------------------------------------------------------
# Attack entry points
# ------------------------------------------------------------------------------

func play_strike_windup(order: StrikeWindupOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return

	_strike_gen += 1
	var gen := _strike_gen

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


func _ranged_pulse_async(delay_sec: float, up_t: float, down_t: float, gen: int) -> void:
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
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
	if spawn_t > 0.0:
		await get_tree().create_timer(spawn_t).timeout

	if !is_instance_valid(self) or gen != _strike_gen:
		return

	var proj_path := String(order.projectile_scene_path)
	if proj_path == "":
		proj_path = "res://VFX/projectiles/fireball/fireball.tscn"

	var scene: PackedScene = FxLibrary.get_scene(proj_path)
	if scene == null:
		push_warning("Missing projectile scene: %s" % proj_path)
		return

	var projectile := scene.instantiate() as Node2D
	if projectile == null:
		return

	battle_view.add_child(projectile)

	var start_pos := _get_projectile_origin_global()
	var end_pos := battle_view.get_mean_target_position_global(target_ids, start_pos)
	end_pos.y = start_pos.y

	var group := get_parent()
	if group is GroupView and !(group as GroupView).faces_right:
		projectile.scale.x *= -1

	projectile.global_position = start_pos

	var t := projectile.create_tween().set_trans(Tween.TRANS_LINEAR)
	t.tween_property(projectile, "global_position", end_pos, maxf(travel_t, 0.01))

	# Projectile owns its impact + lifetime.
	t.tween_callback(func():
		if !is_instance_valid(projectile):
			return
		if projectile.has_method("play_impact"):
			projectile.call("play_impact")
		else:
			projectile.queue_free()
	)


func _get_projectile_origin_global() -> Vector2:
	var height := float(_spec.get(Keys.HEIGHT, 270))
	var offset := Vector2(0, -(height * 0.67))
	return global_position + offset


# ------------------------------------------------------------------------------
# Receiving hits / death
# ------------------------------------------------------------------------------

func _apply_received_hit(h: HitPresentationInfo, phase_duration: float) -> void:
	play_hit()
	set_health(h.after_health, h.was_lethal)
	pop_damage_number(h.amount)

	if h.was_lethal:
		play_death_reaction(maxf(phase_duration * 0.6, 0.15))


func play_death_reaction(duration: float) -> void:
	if tween_misc:
		tween_misc.kill()

	_cache_base_art_transform_if_needed()
	is_alive = false

	if intent_container != null:
		intent_container.visible = false
	if health_bar != null:
		health_bar.visible = false
	if status_view_grid != null:
		status_view_grid.visible = false

	var dur := maxf(duration, 0.01)
	var base_pos := _get_base_art_pos()
	var base_scale := _get_base_art_scale()

	var slump := Vector2(0, 10.0)
	var shrink_scale := base_scale * 0.96
	var to_col := Color(0, 0, 0, 1.0)

	tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_misc.tween_property(character_art, "modulate", to_col, dur)
	tween_misc.parallel().tween_property(art_parent, "position", base_pos + slump, dur)
	tween_misc.parallel().tween_property(art_parent, "scale", shrink_scale, dur)


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


func pop_damage_number(amount: int) -> void:
	if amount <= 0:
		return
	var scn: PackedScene = FxLibrary.get_scene(DAMAGE_NUMBER_SCN_PATH)
	if scn == null:
		push_warning("Missing DamageNumber scene at %s" % DAMAGE_NUMBER_SCN_PATH)
		return
	var dn := scn.instantiate() as Node2D
	if dn == null:
		return
	add_child(dn)
	if dn.has_method("animate_and_vanish"):
		dn.call("animate_and_vanish", amount, _height_px)


func set_health(new_health: int, was_lethal: bool = false) -> void:
	health = clampi(new_health, 0, max_health)
	if health_bar != null:
		health_bar.update_health_view(max_health, health)
	if was_lethal:
		pass
