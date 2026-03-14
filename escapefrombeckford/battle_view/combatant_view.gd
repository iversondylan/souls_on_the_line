# combatant_view.gd

class_name CombatantView extends Node2D

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

enum Type {ALLY, ENEMY, PLAYER}
enum Mortality {MORTAL, SOULBOUND, DEPLETE}
enum TurnStatus { NONE, TURN_PENDING, TURN_ACTIVE }
var type: Type : set = _set_type
var mortality: Mortality = Mortality.MORTAL
var display_name: String = ""
var cid: int = -1 : set = _set_cid
var character_art_uid: String

var _status_catalog: StatusCatalog = null
var _spec: Dictionary = {}

var health : int = 1
var max_health: int = 2
var is_alive := true
var mana: int = 3
var max_mana: int = 3
var anchor_position: Vector2# = Vector2(0, 0)
var has_anchor_position: bool = false
#var _assets: BattleAssetCache = null
#var is_player := false : set = _set_is_player
#func bind_assets(cache: BattleAssetCache) -> void:
	#_assets = cache

var tween_move: Tween
var tween_strike: Tween
var tween_hit: Tween
var tween_focus: Tween
var tween_misc: Tween

var _strike_gen: int = 0
# ---- Base tracking ----
var _base_art_scale: Vector2 = Vector2.ONE
var _base_art_pos: Vector2 = Vector2.ZERO
var _base_cached := false

var group_index: int = -1 # 0 friendly, 1 enemy

func is_soulbound() -> bool:
	return int(mortality) == int(Mortality.SOULBOUND)

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
		#print("combatant_view _set_type() setting area left monitorable/monitoring to true")
		area_left.monitorable = true
		area_left.monitoring = true

func play_strike_followthrough(order: StrikeFollowthroughOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return

	#if int(order.attack_mode) == Attack.Mode.RANGED:
		#if order.attack_info != null:
			#for i in range(order.attack_info.strikes.size()):
				#var key := int(battle_view.make_projectile_key(int(order.attacker_id), i))
				#var projectile := battle_view.take_projectile(key)
				#if projectile != null and is_instance_valid(projectile):
					#if projectile.has_method("play_impact"):
						#projectile.call("play_impact")
					#else:
						#projectile.queue_free()
		#else:
			#var projectile := battle_view.take_projectile(battle_view.make_projectile_key(int(order.attacker_id), 0))
			#if projectile != null and is_instance_valid(projectile):
				#if projectile.has_method("play_impact"):
					#projectile.call("play_impact")
				#else:
					#projectile.queue_free()

	_apply_followthrough_pose(order)



func play_projectile_impact_for_strike(attacker_id: int, strike_index: int, battle_view: BattleView) -> void:
	if battle_view == null:
		return

	var key := battle_view.make_projectile_key(int(attacker_id), int(strike_index))
	var projectile := battle_view.take_projectile(key)
	if projectile == null or !is_instance_valid(projectile):
		return

	if projectile.has_method("play_impact"):
		projectile.call("play_impact")
	else:
		projectile.queue_free()

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
	_cache_base_art_transform_if_needed()

func _apply_stats_from_spec() -> void:
	# Use spec values for initial UI.
	# Later, you can add dedicated events for health changes etc.
	mortality = int(_spec.get(Keys.MORTALITY, CombatantView.Mortality.MORTAL))
	max_health = int(_spec.get(Keys.MAX_HEALTH, 0))
	health = int(_spec.get(Keys.HEALTH, 0))
	# health_bar.update_health_from_numbers(hp, max_hp) # adapt to your API
	health_bar.update_health_view(max_health, health)

func set_pending_turn_glow(status: TurnStatus) -> void:
	match status:
		TurnStatus.TURN_ACTIVE:
			pending_turn_glow.show()
			# Unmodulated
			pending_turn_glow.modulate = Color(1.0, 0.65, 0.25)

		TurnStatus.TURN_PENDING:
			pending_turn_glow.show()
			# Cool it toward blue while preserving intensity
			pending_turn_glow.modulate = Color(0.45, 0.65, 1.0)

		TurnStatus.NONE:
			pending_turn_glow.hide()

func on_focus(order: FocusOrder) -> void:
	var involved := false
	if cid == order.attacker_id:
		involved = true
	else:
		for tid in order.target_ids:
			if cid == int(tid):
				involved = true
				break
	
	if tween_focus:
		tween_focus.kill()
	
	var target_scale := Vector2.ONE * (order.scale_involved if involved else order.scale_uninvolved)
	var target_dim := 1.0 if involved else order.dim_uninvolved
	
	# drift: just a small horizontal nudge toward center
	var drift := 0.0
	if involved:
		var sign := 1.0 if (get_parent() as GroupView).faces_right else -1.0
		drift = sign * order.drift_involved
	
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", target_scale, order.duration)
	var x: float = anchor_position.x + drift
	tween_focus.parallel().tween_property(self, "position", Vector2(x, 0), order.duration)
	tween_focus.parallel().tween_property(self, "modulate", Color(target_dim, target_dim, target_dim, 1.0), order.duration)

func clear_focus(duration: float) -> void:
	if tween_focus:
		tween_focus.kill()
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", Vector2.ONE, duration)
	tween_focus.parallel().tween_property(self, "position", anchor_position, duration)
	tween_focus.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), duration)

func set_anchor_position(_position: Vector2, ctx: GroupLayoutOrder) -> void:
	anchor_position = _position
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

func show_targeted_arrow(show_it: bool) -> void:
	if targeted_arrow != null:
		targeted_arrow.visible = show_it

func apply_strike_windup(order: StrikeWindupOrder) -> void:
	if tween_strike:
		tween_strike.kill()
	
	var base_scale := _get_base_art_scale()
	var target_scale := Vector2(base_scale.x * order.x_scale, base_scale.y * order.y_scale)
	
	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", target_scale, order.duration)

func play_strike_windup(order: StrikeWindupOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return

	_strike_gen += 1
	var gen := _strike_gen

	_apply_windup_pose(order)

	if int(order.attack_mode) != Attack.Mode.RANGED:
		return

	_schedule_projectile_spawn(order, battle_view, gen)

func _schedule_projectile_spawn(order: StrikeWindupOrder, battle_view: BattleView, gen: int) -> void:
	if order.attack_info == null or order.attack_info.strikes.is_empty():
		var spawn_t := clampf(order.duration * float(order.projectile_spawn_ratio), 0.0, order.duration)
		var travel_t := maxf(order.duration - spawn_t, 0.001)
		_spawn_projectile_async(order, battle_view, gen, spawn_t, travel_t, 0, order.target_ids)
		return

	for i in range(order.attack_info.strikes.size()):
		var s := (order.attack_info.strikes[i])
		if s == null:
			continue

		var spawn_t := clampf(order.duration * s.t0_ratio, 0.0, order.duration)
		var end_t := clampf(order.duration * s.t1_ratio, spawn_t, order.duration)
		var travel_t := maxf(end_t - spawn_t, 0.001)

		_spawn_projectile_async(
			order,
			battle_view,
			gen,
			spawn_t,
			travel_t,
			i,
			s.target_ids
		)

func _spawn_projectile_async(
	order: StrikeWindupOrder,
	battle_view: BattleView,
	gen: int,
	spawn_t: float,
	travel_t: float,
	strike_index: int,
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

	var key := battle_view.make_projectile_key(int(order.attacker_id), int(strike_index))
	battle_view.put_projectile(key, projectile)

	var t := projectile.create_tween().set_trans(Tween.TRANS_LINEAR)
	t.tween_property(projectile, "global_position", end_pos, travel_t)

func _apply_windup_pose(order: StrikeWindupOrder) -> void:
	if tween_strike:
		tween_strike.kill()
	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# drift toward center-ish (cheap): drift depends on facing
	var drift := order.drift_x
	var g := get_parent()
	if g is GroupView and !(g as GroupView).faces_right:
		drift = -drift
	
	tween_strike.tween_property(art_parent, "scale", Vector2(order.x_scale, order.y_scale), order.duration * 0.6)
	tween_strike.parallel().tween_property(art_parent, "position:x", art_parent.position.x + drift, order.duration * 0.6)

func apply_strike_followthrough(order: StrikeFollowthroughOrder) -> void:
	if tween_strike:
		tween_strike.kill()
	
	var base_scale := _get_base_art_scale()
	var snap_scale := Vector2(base_scale.x * order.x_scale, base_scale.y * order.y_scale)
	
	var snap_t := maxf(0.001, order.duration * order.snap_ratio)
	var recover_t := maxf(0.001, order.duration - snap_t)
	
	tween_strike = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", snap_scale, snap_t)
	
	# quick shake: do it on focus_offset (best) or character_art.position (acceptable)
	# I’ll show character_art.position since you asked “messing with character_art”
	var base_pos := art_parent.position
	var s := order.shake_px
	
	# small, fast shake during recover
	tween_strike.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "position", base_pos + Vector2(s, 0), recover_t * 0.20)
	tween_strike.tween_property(art_parent, "position", base_pos + Vector2(-s, 0), recover_t * 0.20)
	tween_strike.tween_property(art_parent, "position", base_pos + Vector2(s * 0.6, 0), recover_t * 0.20)
	tween_strike.tween_property(art_parent, "position", base_pos, recover_t * 0.40)
	
	# recover scale back to base by end
	tween_strike.parallel().tween_property(art_parent, "scale", base_scale, recover_t)

func _apply_followthrough_pose(order: StrikeFollowthroughOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var strike_mult := maxi(1, order.strike_count)
	var hit_mult := maxi(1, order.total_hit_count)

	var snap_scale_x := order.x_scale + 0.04 * float(strike_mult - 1)
	var snap_scale_y := order.y_scale - 0.02 * float(strike_mult - 1)
	var shake := order.shake_px + 1.5 * float(hit_mult - 1)

	if order.has_lethal_hit:
		shake += 2.0

	var snap_scale := Vector2(
		base_scale.x * snap_scale_x,
		base_scale.y * snap_scale_y
	)

	var snap_t := maxf(order.duration * float(order.snap_ratio), 0.01)
	var recover_t := maxf(order.duration - snap_t, 0.01)

	tween_strike.tween_property(art_parent, "scale", snap_scale, snap_t)

	tween_strike.parallel().tween_property(
		art_parent,
		"position",
		base_pos + Vector2(shake, 0),
		snap_t * 0.5
	)
	tween_strike.tween_property(
		art_parent,
		"position",
		base_pos + Vector2(-shake, 0),
		snap_t * 0.5
	)

	tween_strike.tween_property(art_parent, "scale", base_scale, recover_t).set_ease(Tween.EASE_IN_OUT)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, recover_t).set_ease(Tween.EASE_IN_OUT)

func clear_strike_pose(duration: float) -> void:
	if tween_strike:
		tween_strike.kill()
	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "scale", Vector2.ONE, maxf(duration, 0.01))

func _get_projectile_origin_global() -> Vector2:
	var height := float(_spec.get(Keys.HEIGHT, 270))
	var offset := Vector2(0, -(height * 0.67))
	return global_position + offset

#func _get_mean_target_global(target_ids: Array[int]) -> Vector2:
	#if target_ids.is_empty():
		#return global_position
	#var sum := Vector2.ZERO
	#var n := 0
	#for tid in target_ids:
		#var tv := (get_parent() as BattleView).get_mean_target_position_global(target_ids, global_position)
		##var tv := (get_tree().get_first_node_in_group("battle_view") as Node) # don't do this
		#n += 1
	#return sum / float(maxi(n, 1))

func play_death_windup(o: DeathWindupOrder) -> void:
	if o == null:
		return

	# Kill misc tween if it exists
	if tween_misc:
		tween_misc.kill()

	_cache_base_art_transform_if_needed()

	var dur := maxf(o.duration, 0.01)

	# We fade the ART to black (not the whole node) so UI (health/status) can decide what to do later.
	# If you want everything to go dark, tween "modulate" on self instead.
	var to_col := Color(0, 0, 0, 1.0) if o.to_black else Color(1, 1, 1, 1.0)

	# Optional little "slump"
	var base_pos := _get_base_art_pos()
	var slump := Vector2(0, float(o.slump_px))

	# Optional small shrink
	var base_scale := _get_base_art_scale()
	var shrink_scale := base_scale * float(o.shrink)

	tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_misc.tween_property(character_art, "modulate", to_col, dur)
	tween_misc.parallel().tween_property(art_parent, "position", base_pos + slump, dur)
	tween_misc.parallel().tween_property(art_parent, "scale", shrink_scale, dur)

func on_death_followthrough(duration: float) -> void:
	# Option: hide UI bits quickly so the corpse doesn't retain bars/intent
	if intent_container != null:
		intent_container.visible = false
	if health_bar != null:
		health_bar.visible = false
	if status_view_grid != null:
		status_view_grid.visible = false

	# Keep the dark sprite visible until DIED queues it free.
	# If you want it to fade out too, do it here:
	#if tween_misc:
		#tween_misc.kill()
	#tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	#tween_misc.tween_property(self, "modulate:a", 0.0, maxf(duration, 0.01))

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

#func _set_character_art(_uid: String) -> void:
	#character_art.texture = load(_uid) as Texture

func _on_target_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if event.is_action_pressed("mouse_click"):
		# combatant_view.gd (wherever you emit clicked/hover)
		if !is_alive:
			return
		Events.combatant_view_clicked.emit(self)
