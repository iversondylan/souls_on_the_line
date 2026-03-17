# combatant_view.gd
#
# TIMING AUTHORSHIP PHILOSOPHY
# ------------------------------------------------------------------------------
# Upstream should tell CombatantView only:
# - when a phase starts
# - how long the whole phase owns
# - metadata like attack_mode / strike_count / target_ids
#
# CombatantView owns:
# - all intra-phase feel
# - pulse shape
# - melee windup/followthrough feel
# - ranged launch timing within windup
# - projectile travel duration
# - impact timing behavior
#
# If something "looks wrong", most likely timing levers are in:
# - on_focus / clear_focus
# - _play_ranged_windup_pulses
# - _get_ranged_launch_times
# - _schedule_projectile_spawn
# - _apply_windup_pose
# - _apply_followthrough_pose
# - play_death_windup
#
# ------------------------------------------------------------------------------

class_name CombatantView extends Node2D


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


# ------------------------------------------------------------------------------
# Core state
# ------------------------------------------------------------------------------

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

var _is_focus_active: bool = false

var health : int = 1
var max_health: int = 2
var is_alive := true
var mana: int = 3
var max_mana: int = 3

var anchor_position: Vector2
var has_anchor_position: bool = false

var tween_move: Tween
var tween_strike: Tween
var tween_hit: Tween
var tween_focus: Tween
var tween_misc: Tween

# Used to invalidate old async attack pulses/projectile spawns
var _strike_gen: int = 0

# Cached resting transform for art_parent
var _base_art_scale: Vector2 = Vector2.ONE
var _base_art_pos: Vector2 = Vector2.ZERO
var _base_cached := false

var group_index: int = -1 # 0 friendly, 1 enemy


# ------------------------------------------------------------------------------
# Quick map of timing levers
# ------------------------------------------------------------------------------
#
# FOCUS
# - on_focus():
#	- order.duration
#	- order.scale_involved
#	- order.dim_uninvolved
#	- order.drift_involved
#
# REFOCUS / CLEAR
# - clear_focus(duration)
#
# GROUP REPOSITION
# - set_anchor_position():
#	- hardcoded 0.12
#
# RANGED ATTACKS
# - play_strike_windup()
# - _play_ranged_windup_pulses()
# - _apply_ranged_pulse_async():
#	- pulse_up_t
#	- pulse_down_t
#	- peak_scale
#	- peak_pos
# - _get_ranged_launch_times():
#	- travel_t
#	- inter-shot gap currently 0.15
# - _schedule_projectile_spawn():
#	- flat travel_t currently 0.3
#
# MELEE ATTACKS
# - _apply_windup_pose():
#	- windup_scale
#	- windup_pos
#	- snap_t ratio currently 0.42
# - _apply_followthrough_pose():
#	- snap_scale_x / snap_scale_y
#	- shake
#	- snap_t ratio currently 0.18
#	- recover_t minimum currently 0.06
#
# DEATH
# - play_death_windup():
#	- shrink
#	- slump_px
#	- easing
#
# ------------------------------------------------------------------------------


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


func _on_target_area_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
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
# Focus timing
# ------------------------------------------------------------------------------
#
# Main focus levers:
# - order.duration -> total focus tween time
# - order.scale_involved
# - order.scale_uninvolved
# - order.dim_uninvolved
# - order.drift_involved
#
# If focus feels too floaty:
# - reduce drift
# - reduce duration upstream or in order
# - reduce involved scale
#
# ------------------------------------------------------------------------------

func on_focus(order: FocusOrder) -> void:
	_is_focus_active = true

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

	var drift := 0.0
	if involved:
		var sign := 1.0 if (get_parent() as GroupView).faces_right else -1.0
		drift = sign * order.drift_involved
	
	var reduced_duration := order.duration * 0.75
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", target_scale, reduced_duration)

	var x: float = anchor_position.x + drift
	tween_focus.parallel().tween_property(self, "position", Vector2(x, 0), reduced_duration)
	#print("combatant_view() on_focus() duration: ", order.duration)
	tween_focus.parallel().tween_property(self, "modulate", Color(target_dim, target_dim, target_dim, 1.0), reduced_duration)


func clear_focus(duration: float) -> void:
	_is_focus_active = false

	if tween_focus:
		tween_focus.kill()

	if tween_move:
		tween_move.kill()
	var reduced_duration := duration * 0.75
	tween_focus = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_focus.tween_property(self, "scale", Vector2.ONE, reduced_duration)
	tween_focus.parallel().tween_property(self, "position", anchor_position, reduced_duration)
	tween_focus.parallel().tween_property(self, "modulate", Color(1, 1, 1, 1), reduced_duration)


# ------------------------------------------------------------------------------
# Group movement timing
# ------------------------------------------------------------------------------
#
# Lever:
# - 0.12 reposition tween in set_anchor_position()
#
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
#
# Responsibility split:
# - play_strike_windup(): choose ranged vs melee windup behavior
# - play_strike_followthrough(): choose ranged vs melee followthrough behavior
#
# Important:
# - RANGED followthrough currently does NO body motion, only projectile impacts.
# - MELEE followthrough uses _apply_followthrough_pose().
#
# ------------------------------------------------------------------------------

func play_strike_windup(order: StrikeWindupOrder, battle_view: BattleView) -> void:
	#print("combatant_view.gd play_strike_windup() strike_dount: ", order.strike_count)

	if order == null or battle_view == null:
		return

	_strike_gen += 1
	var gen := _strike_gen

	if int(order.attack_mode) == int(Attack.Mode.RANGED):
		_play_ranged_windup_pulses(order, battle_view, gen)
		_schedule_projectile_spawn(order, battle_view, gen)
		return

	_apply_windup_pose(order)


func play_strike_followthrough(order: StrikeFollowthroughOrder, battle_view: BattleView) -> void:
	if order == null or battle_view == null:
		return

	# RANGED: no followthrough body motion, only impact resolution
	if int(order.attack_mode) == int(Attack.Mode.RANGED):
		var count := maxi(1, order.strike_count)
		for i in range(count):
			play_projectile_impact_for_strike(order.attacker_id, i, battle_view)
		return

	# MELEE: body motion owned here
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

func play_attack_received_followthrough(info: AttackPresentationInfo, phase_duration: float) -> void:
	if info == null:
		return

	for s in info.strikes:
		if s == null:
			continue

		for h in s.hits:
			if h == null:
				continue
			if int(h.target_id) != int(cid):
				continue

			_play_received_hit_async(h, phase_duration)

# ------------------------------------------------------------------------------
# Generic windup helper
# ------------------------------------------------------------------------------
#
# This is more of a plain "scale over duration" helper.
# Your real melee feel currently lives in _apply_windup_pose().
#
# ------------------------------------------------------------------------------

func apply_strike_windup(order: StrikeWindupOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	var base_scale := _get_base_art_scale()
	var target_scale := Vector2(base_scale.x * order.x_scale, base_scale.y * order.y_scale)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", target_scale, order.duration)


# ------------------------------------------------------------------------------
# RANGED WINDUP TIMING
# ------------------------------------------------------------------------------
#
# This is where ranged firing feel is authored.
#
# Timing levers:
# - _get_ranged_launch_times()
#	- flat travel_t
#	- first launch time = windup_duration - travel_t
#	- extra shot spacing currently +0.15 sec
#
# - _play_ranged_windup_pulses()
#	- pulse_up_t
#	- pulse_down_t
#	- pulse_start = launch_t - pulse_up_t
#
# - _apply_ranged_pulse_async()
#	- peak_scale
#	- peak_pos
#
# Current intended feel:
# - body peaks exactly at launch
# - projectile launches at that peak
# - projectile travels during late windup / early followthrough
#
# ------------------------------------------------------------------------------

func _play_ranged_windup_pulses(order: StrikeWindupOrder, battle_view: BattleView, gen: int) -> void:
	var count := maxi(1, order.strike_count)
	var launch_times: Array[float] = _get_ranged_launch_times(order.duration, count)

	for i in range(launch_times.size()):
		var launch_t := launch_times[i]

		# TIMING LEVERS: ranged pulse shape
		var pulse_up_t := 0.06
		var pulse_down_t := 0.05
		var pulse_start := maxf(0.0, launch_t - pulse_up_t)

		_apply_single_ranged_pulse(
			order,
			pulse_start,
			pulse_up_t,
			pulse_down_t
		)


func _apply_single_ranged_pulse(
	order: StrikeWindupOrder,
	delay_sec: float,
	up_t: float,
	down_t: float
) -> void:
	var my_gen := _strike_gen
	_apply_ranged_pulse_async(order, delay_sec, up_t, down_t, my_gen)


func _apply_ranged_pulse_async(
	order: StrikeWindupOrder,
	delay_sec: float,
	up_t: float,
	down_t: float,
	gen: int
) -> void:
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout

	if !is_instance_valid(self) or gen != _strike_gen:
		return

	if tween_strike:
		tween_strike.kill()

	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	# FEEL LEVERS: ranged firing pose
	var peak_scale := Vector2(base_scale.x * 0.97, base_scale.y * 1.03)
	var peak_pos := base_pos + Vector2(0, -3)

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", peak_scale, maxf(up_t, 0.01))
	tween_strike.parallel().tween_property(art_parent, "position", peak_pos, maxf(up_t, 0.01))

	tween_strike.tween_property(art_parent, "scale", base_scale, maxf(down_t, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, maxf(down_t, 0.01)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _play_received_hit_async(h: HitPresentationInfo, phase_duration: float) -> void:
	# no ratios upstream; ratios here are local interpretation of the presentation info
	# if you still want no normalized timing at all eventually, this can shift to index-based timing later

	var delay_sec := 0.0
	# for now use strike ordering / local heuristic if needed
	# or keep t0_ratio here temporarily until you fully remove it from the info classes

	play_hit()
	set_health(h.after_health, h.was_lethal)
	pop_damage_number(h.amount)

	if h.was_lethal:
		play_death_reaction(phase_duration)

func _schedule_projectile_spawn(order: StrikeWindupOrder, battle_view: BattleView, gen: int) -> void:
	var count := maxi(1, order.strike_count)
	var launch_times: Array[float] = _get_ranged_launch_times(order.duration, count)

	# TIMING LEVER: flat projectile travel duration
	var travel_t := 0.3

	for i in range(launch_times.size()):
		var strike_targets: Array[int] = order.target_ids

		if order.attack_info != null and i < order.attack_info.strikes.size():
			var s := order.attack_info.strikes[i]
			if s != null and !s.target_ids.is_empty():
				strike_targets = s.target_ids

		_spawn_projectile_async(
			order,
			battle_view,
			gen,
			launch_times[i],
			travel_t,
			i,
			strike_targets
		)


func _get_ranged_launch_times(windup_duration: float, count: int) -> Array[float]:
	var out: Array[float] = []

	# MASTER TIMING LEVERS FOR RANGED MULTICAST
	var travel_t := 0.3
	var first_launch := maxf(0.0, windup_duration - travel_t)

	if count <= 1:
		out.append(first_launch)
		return out

	# TIMING LEVER: inter-shot spacing
	for i in range(count):
		out.append(first_launch + 0.15 * float(i))

	return out


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

	# VISUAL LEVER:
	# currently projectiles travel horizontally only
	end_pos.y = start_pos.y

	var group := get_parent()
	if group is GroupView and !(group as GroupView).faces_right:
		projectile.scale.x *= -1

	projectile.global_position = start_pos

	var key := battle_view.make_projectile_key(int(order.attacker_id), int(strike_index))
	battle_view.put_projectile(key, projectile)

	var t := projectile.create_tween().set_trans(Tween.TRANS_LINEAR)
	t.tween_property(projectile, "global_position", end_pos, travel_t)


func _get_projectile_origin_global() -> Vector2:
	var height := float(_spec.get(Keys.HEIGHT, 270))

	# VISUAL LEVER: projectile spawn point on body
	var offset := Vector2(0, -(height * 0.67))
	return global_position + offset


# ------------------------------------------------------------------------------
# MELEE WINDUP TIMING
# ------------------------------------------------------------------------------
#
# This is the "stretch / load up" pose before impact.
#
# Main feel levers:
# - windup_scale
# - windup_pos
# - snap_t ratio
#
# If melee windup feels mushy:
# - reduce snap_t
# - exaggerate windup_scale
# - exaggerate drift / vertical offset a bit
#
# ------------------------------------------------------------------------------

func _apply_windup_pose(order: StrikeWindupOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var drift := order.drift_x
	var g := get_parent()
	if g is GroupView and !(g as GroupView).faces_right:
		drift = -drift

	# FEEL LEVERS: melee windup pose
	var windup_scale := Vector2(base_scale.x * 0.88, base_scale.y * 1.16)
	var windup_pos := base_pos + Vector2(drift, -4)

	# TIMING LEVER: how quickly the windup reaches its loaded pose
	var snap_t := maxf(order.duration * 0.42, 0.05)

	tween_strike.tween_property(art_parent, "scale", windup_scale, snap_t)
	tween_strike.parallel().tween_property(art_parent, "position", windup_pos, snap_t)


# ------------------------------------------------------------------------------
# Generic followthrough helper
# ------------------------------------------------------------------------------
#
# Older / alternate helper. Your current melee feel is in _apply_followthrough_pose().
#
# ------------------------------------------------------------------------------

func apply_strike_followthrough(order: StrikeFollowthroughOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	var base_scale := _get_base_art_scale()
	var snap_scale := Vector2(base_scale.x * order.x_scale, base_scale.y * order.y_scale)

	var snap_t := maxf(0.001, order.duration * order.snap_ratio)
	var recover_t := maxf(0.001, order.duration - snap_t)

	tween_strike = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", snap_scale, snap_t)

	var base_pos := art_parent.position
	var s := order.shake_px

	tween_strike.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "position", base_pos + Vector2(s, 0), recover_t * 0.20)
	tween_strike.tween_property(art_parent, "position", base_pos + Vector2(-s, 0), recover_t * 0.20)
	tween_strike.tween_property(art_parent, "position", base_pos + Vector2(s * 0.6, 0), recover_t * 0.20)
	tween_strike.tween_property(art_parent, "position", base_pos, recover_t * 0.40)

	tween_strike.parallel().tween_property(art_parent, "scale", base_scale, recover_t)


# ------------------------------------------------------------------------------
# MELEE FOLLOWTHROUGH TIMING
# ------------------------------------------------------------------------------
#
# This is the main "punch" feel after impact.
#
# Main feel levers:
# - snap_scale_x / snap_scale_y
# - shake
# - snap_t ratio
# - recover_t minimum
#
# If melee followthrough feels mushy:
# - increase snap_scale_x
# - decrease snap_scale_y
# - decrease snap_t
# - shorten recover_t
#
# ------------------------------------------------------------------------------

func _apply_followthrough_pose(order: StrikeFollowthroughOrder) -> void:
	if tween_strike:
		tween_strike.kill()

	tween_strike = create_tween()

	var base_scale := _get_base_art_scale()
	var base_pos := _get_base_art_pos()

	var strike_mult := maxi(1, order.strike_count)
	var hit_mult := maxi(1, order.total_hit_count)

	# FEEL LEVERS: melee impact exaggeration
	var snap_scale_x := 1.16 + 0.03 * float(strike_mult - 1)
	var snap_scale_y := 0.84 - 0.02 * float(strike_mult - 1)
	var shake := 8.0 + 1.5 * float(hit_mult - 1)

	if order.has_lethal_hit:
		shake += 2.0

	var snap_scale := Vector2(
		base_scale.x * snap_scale_x,
		base_scale.y * snap_scale_y
	)

	# TIMING LEVERS: impact snap and recovery
	var snap_t := maxf(order.duration * 0.18, 0.04)
	var recover_t := maxf(order.duration - snap_t, 0.06)

	tween_strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween_strike.tween_property(art_parent, "scale", snap_scale, snap_t)
	tween_strike.parallel().tween_property(
		art_parent,
		"position",
		base_pos + Vector2(shake, 0),
		snap_t
	)

	tween_strike.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "scale", base_scale, recover_t)
	tween_strike.parallel().tween_property(art_parent, "position", base_pos, recover_t)


func clear_strike_pose(duration: float) -> void:
	if tween_strike:
		tween_strike.kill()

	tween_strike = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_strike.tween_property(art_parent, "scale", Vector2.ONE, maxf(duration, 0.01))


# ------------------------------------------------------------------------------
# Death timing
# ------------------------------------------------------------------------------
#
# Main feel levers:
# - shrink
# - slump_px
# - duration from order
#
# ------------------------------------------------------------------------------

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

#func play_death_windup(o: DeathWindupOrder) -> void:
	#if o == null:
		#return
#
	#if tween_misc:
		#tween_misc.kill()
#
	#_cache_base_art_transform_if_needed()
#
	#var dur := maxf(o.duration, 0.01)
	#var to_col := Color(0, 0, 0, 1.0) if o.to_black else Color(1, 1, 1, 1.0)
#
	#var base_pos := _get_base_art_pos()
	#var slump := Vector2(0, float(o.slump_px))
#
	#var base_scale := _get_base_art_scale()
	#var shrink_scale := base_scale * float(o.shrink)
#
	#tween_misc = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	#tween_misc.tween_property(character_art, "modulate", to_col, dur)
	#tween_misc.parallel().tween_property(art_parent, "position", base_pos + slump, dur)
	#tween_misc.parallel().tween_property(art_parent, "scale", shrink_scale, dur)


#func on_death_followthrough(duration: float) -> void:
	#if intent_container != null:
		#intent_container.visible = false
	#if health_bar != null:
		#health_bar.visible = false
	#if status_view_grid != null:
		#status_view_grid.visible = false


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
# Stubs / future work
# ------------------------------------------------------------------------------

func _set_name_label(_nm: String) -> void:
	pass


func play_summon_fx() -> void:
	pass


func play_targeting() -> void:
	pass


func show_targeted(_is_targeted: bool) -> void:
	pass


func play_hit() -> void:
	pass


func pop_damage_number(_amount: int) -> void:
	pass


func play_attack_react() -> void:
	pass


func add_status_icon(_status_id: StringName) -> void:
	pass


func remove_status_icon(_status_id: StringName) -> void:
	pass


func set_health(new_health: int, was_lethal: bool = false) -> void:
	health = clampi(new_health, 0, max_health)
	health_bar.update_health_view(max_health, health)
	if was_lethal:
		pass
