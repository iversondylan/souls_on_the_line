# turn_order_spark_controller.gd
class_name TurnOrderSparkController
extends Node2D

signal finished
signal canceled

@onready var turn_preview_number_scn: PackedScene = preload("res://scenes/ui/turn_preview_number.tscn")
@onready var ordinals_parent: Node2D = $OrdinalsParent

@export var height_above_feet: float = 100.0

@export var time_between_fighters: float = 0.40

# Arc settings (replaces "beyond/before + blip" wrap)
@export var arc_time_mult: float = 2.0
@export var arc_raise_px: float = 140.0

@export var default_spacing: float = 240.0 # kept but unused now (safe to delete later)

# --- INTRO / FEEL ---
@export var intro_grow_mult: float = 1.25 # unused now (safe to delete later)
@export var intro_grow_duration: float = 0.55
@export var intro_linger: float = 0.90

@export var intro_label_fade: float = 0.90

# --- PASS "PULSE" (scale bump only; no color flash) ---
@export var pulse_scale_mult: float = 1.20
@export var pulse_total_time: float = 0.22

# --- FINISH ---
@export var fade_out_duration: float = 0.75

@export var base_blue: Color = Color(0.45, 0.65, 1.0)
@export var ghost_alpha: float = 0.65

@onready var _label: RichTextLabel = $SparkLabel
@onready var _spark: Sprite2D = $Spark

var _active := false
var _travel: Tween
var _label_fade: Tween
var _base_scale: Vector2 = Vector2.ONE


func _ready() -> void:
	hide()
	if _spark:
		_base_scale = _spark.scale
		_spark.modulate.a = 0.0
	if _label:
		_label.modulate = base_blue
		_label.modulate.a = 0.0


func is_active() -> bool:
	return _active


func play(path: TurnOrderPath) -> void:
	if _active:
		return
	if !path or !path.is_valid():
		return
	if !_spark or !_label:
		return

	_active = true
	show()

	_kill_travel()
	_kill_label_fade()
	_clear_ordinals()

	_spark.visible = true
	_label.visible = true

	_base_scale = _spark.scale

	# Lifted key point
	var player_p := _lift(path.player_pos)

	# Lifted traversal lists (already in child/turn/spatial order)
	var behind := _lift_positions(path.behind_friendlies)          # move left through these
	var enemies := _lift_positions(path.enemies_front_to_back)     # move right through these
	var in_front := _lift_positions(path.in_front_friendlies)      # move left through these

	var has_enemies := !enemies.is_empty()

	# Reset presentation
	_spark.global_position = player_p
	_spark.scale = _base_scale
	_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, 0.0)

	# Label: place ONCE (does not move), fade in during spark alpha-in
	_place_label_once_at_spark()
	_label.modulate.a = 0.0
	_start_label_fade_in()

	_travel = get_tree().create_tween()
	_travel.set_trans(Tween.TRANS_LINEAR)
	_travel.set_ease(Tween.EASE_IN_OUT)

	# --- Intro: spark alpha-in + linger ---
	_travel.tween_property(_spark, "modulate:a", ghost_alpha, maxf(intro_grow_duration, 0.01))
	_travel.tween_interval(maxf(intro_linger, 0.0))

	# Start moving: label fades OUT starting exactly here
	_travel.tween_callback(func():
		if !_active:
			return
		_start_label_fade()
	)

	# Ordinals start at 1
	var ordinal_ref := [1]

	# ============================================================
	# A) player -> leftward through rear allies (behind)
	# ============================================================
	_append_traverse(_travel, behind, ordinal_ref)

	# Arc from rear friendly -> enemy front (or skip if no enemies)
	var rear_friendly := player_p if behind.is_empty() else behind[behind.size() - 1]
	if has_enemies:
		var enemy_front := enemies[0]
		_append_arc(_travel, rear_friendly, enemy_front, _arc_time())

	# ============================================================
	# B) rightward through enemies
	# ============================================================
	if has_enemies:
		# We ended the arc at enemies[0]; count that as a pass event.
		_append_pass_event(_travel, ordinal_ref)

		for i in range(1, enemies.size()):
			_append_move(_travel, enemies[i], _tb())
			_append_pass_event(_travel, ordinal_ref)

	# Arc from rear enemy -> first in_front (or player)
	var rear_enemy := Vector2.ZERO
	if has_enemies:
		rear_enemy = enemies[enemies.size() - 1]
	else:
		# No enemies: just treat "rear enemy" as current spark position (player-ish flow)
		rear_enemy = _spark.global_position

	var friendly_target := player_p
	if !in_front.is_empty():
		friendly_target = in_front[0]

	_append_arc(_travel, rear_enemy, friendly_target, _arc_time())

	# ============================================================
	# C) leftward through in-front friendlies -> player
	# ============================================================
	if !in_front.is_empty():
		# We ended the arc at in_front[0]; count that as a pass event.
		_append_pass_event(_travel, ordinal_ref)

		for i in range(1, in_front.size()):
			_append_move(_travel, in_front[i], _tb())
			_append_pass_event(_travel, ordinal_ref)

		_append_move(_travel, player_p, _tb())
	else:
		# We arced straight to player; no ordinal on player.
		pass

	_travel.tween_callback(func():
		if !_active:
			return
		_finish_fade_and_numbers()
	)


func cancel() -> void:
	if !_active:
		return
	_cleanup()
	canceled.emit()


# ------------------------------------------------------------
# Label placement + fade (label does NOT move)
# ------------------------------------------------------------

func _start_label_fade_in() -> void:
	_kill_label_fade()
	_label_fade = get_tree().create_tween()
	_label_fade.set_trans(Tween.TRANS_LINEAR)
	_label_fade.set_ease(Tween.EASE_IN_OUT)
	_label_fade.tween_property(_label, "modulate:a", ghost_alpha, maxf(intro_grow_duration, 0.01))

func _place_label_once_at_spark() -> void:
	_label.global_position = _spark.global_position
	_label.global_position -= _label.size * 0.5

func _start_label_fade() -> void:
	_kill_label_fade()
	_label_fade = get_tree().create_tween()
	_label_fade.set_trans(Tween.TRANS_LINEAR)
	_label_fade.set_ease(Tween.EASE_IN_OUT)
	_label_fade.tween_property(_label, "modulate:a", 0.0, maxf(intro_label_fade, 0.01))


# ------------------------------------------------------------
# Travel helpers
# ------------------------------------------------------------

func _append_traverse(t: Tween, pts: Array[Vector2], ordinal_ref: Array) -> void:
	for p in pts:
		_append_move(t, p, _tb())
		_append_pass_event(t, ordinal_ref)

func _append_move(t: Tween, target: Vector2, duration: float) -> void:
	t.tween_property(_spark, "global_position", target, maxf(duration, 0.001))

func _append_pass_event(t: Tween, ordinal_ref: Array) -> void:
	t.tween_callback(func():
		if !_active:
			return
		_spawn_preview_number(ordinal_ref[0])
		ordinal_ref[0] += 1
		_scale_bump_only()
	)

func _tb() -> float:
	return maxf(time_between_fighters, 0.01)

func _arc_time() -> float:
	return maxf(time_between_fighters * arc_time_mult, 0.01)

# Quadratic bezier arc from from_pos -> to_pos, with a mid control point raised upward.
func _append_arc(t: Tween, from_pos: Vector2, to_pos: Vector2, duration: float) -> void:
	var ctrl := (from_pos + to_pos) * 0.5
	ctrl.y -= absf(arc_raise_px)

	var p0 := from_pos
	var p1 := ctrl
	var p2 := to_pos

	# Ensure spark starts exactly at from_pos for the arc segment
	t.tween_callback(func():
		if !_active:
			return
		_spark.global_position = p0
	)

	t.tween_method(
		func(alpha: float) -> void:
			if !_active:
				return
			# Quadratic Bezier: (1-a)^2 p0 + 2(1-a)a p1 + a^2 p2
			var a := clampf(alpha, 0.0, 1.0)
			var inv := 1.0 - a
			var pos := (inv * inv) * p0 + (2.0 * inv * a) * p1 + (a * a) * p2
			_spark.global_position = pos,
		0.0, 1.0, maxf(duration, 0.001)
	)


# ------------------------------------------------------------
# Preview numbers + pulse
# ------------------------------------------------------------

func _spawn_preview_number(n: int) -> void:
	if !turn_preview_number_scn or !ordinals_parent:
		return

	var node := turn_preview_number_scn.instantiate() as TurnPreviewNumber
	if !node:
		return

	ordinals_parent.add_child(node)
	node.set_as_top_level(true)
	node.global_position = _spark.global_position
	node.set_ordinal(n)

func _scale_bump_only() -> void:
	var half := maxf(pulse_total_time * 0.5, 0.01)
	var t := get_tree().create_tween()
	t.set_trans(Tween.TRANS_LINEAR)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_spark, "scale", _base_scale * pulse_scale_mult, half)
	t.tween_property(_spark, "scale", _base_scale, half)


# ------------------------------------------------------------
# Finish / lifecycle
# ------------------------------------------------------------

func _finish_fade_and_numbers() -> void:
	_kill_travel()
	_travel = get_tree().create_tween()
	_travel.set_trans(Tween.TRANS_LINEAR)
	_travel.set_ease(Tween.EASE_IN_OUT)

	_travel.tween_property(_spark, "modulate:a", 0.0, maxf(fade_out_duration, 0.01))
	_travel.tween_callback(func():
		_fade_all_ordinals()
	)
	_travel.tween_interval(TurnPreviewNumber.FADE_TIME)
	_travel.tween_callback(func():
		_cleanup()
		finished.emit()
	)

func _fade_all_ordinals() -> void:
	if !ordinals_parent:
		return
	for child in ordinals_parent.get_children():
		var n := child as TurnPreviewNumber
		if n and is_instance_valid(n):
			n.fade_out()

func _cleanup() -> void:
	_kill_travel()
	_kill_label_fade()
	_clear_ordinals()
	_active = false

	if _spark and is_instance_valid(_spark):
		_spark.visible = false
		_spark.scale = _base_scale
		_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, 0.0)

	if _label and is_instance_valid(_label):
		_label.visible = false
		_label.modulate.a = 0.0

func _clear_ordinals() -> void:
	if !ordinals_parent:
		return
	for child in ordinals_parent.get_children():
		if child and is_instance_valid(child):
			child.queue_free()

func _kill_travel() -> void:
	if _travel and is_instance_valid(_travel):
		_travel.kill()
	_travel = null

func _kill_label_fade() -> void:
	if _label_fade and is_instance_valid(_label_fade):
		_label_fade.kill()
	_label_fade = null


# ------------------------------------------------------------
# Position
# ------------------------------------------------------------

func _lift(p: Vector2) -> Vector2:
	return p + Vector2(0.0, -height_above_feet)

func _lift_positions(arr: Array[Vector2]) -> Array[Vector2]:
	var out: Array[Vector2] = []
	out.resize(arr.size())
	for i in range(arr.size()):
		out[i] = _lift(arr[i])
	return out


## turn_order_spark_controller.gd
#class_name TurnOrderSparkController
#extends Node2D
#
#signal finished
#signal canceled
#
#@onready var turn_preview_number_scn: PackedScene = preload("res://scenes/ui/turn_preview_number.tscn")
#@onready var ordinals_parent: Node2D = $OrdinalsParent
#
#@export var height_above_feet: float = 100.0
#
## One knob for timing once it starts moving.
#@export var time_between_fighters: float = 0.450
#
## Instant-ish blip (must be > 0 for tween consistency)
#@export var blip_duration: float = 0.001
#
#@export var default_spacing: float = 240.0
#
## --- INTRO / FEEL ---
#@export var intro_grow_mult: float = 1.25
#@export var intro_grow_duration: float = 0.55
#@export var intro_linger: float = 0.90
#
## Label fades starting exactly when movement begins
#@export var intro_label_fade: float = 0.90
#
## --- PASS "PULSE" (scale bump only; no color flash) ---
#@export var pulse_scale_mult: float = 1.20
#@export var pulse_total_time: float = 0.22
#
## --- FINISH ---
#@export var fade_out_duration: float = 0.75
#
#@export var base_blue: Color = Color(0.45, 0.65, 1.0)
#@export var ghost_alpha: float = 0.65
#
#@onready var _label: RichTextLabel = $SparkLabel
#@onready var _spark: Sprite2D = $Spark
#
#var _active := false
#
## Separate tweens:
#var _travel: Tween
#var _label_fade: Tween
#
#var _base_scale: Vector2 = Vector2.ONE
#
#
#func _ready() -> void:
	#hide()
	#if _spark:
		#_base_scale = _spark.scale
		#_spark.modulate.a = 0.0
	#if _label:
		#_label.modulate = base_blue
		#_label.modulate.a = 0.0
		#
#
#
#func is_active() -> bool:
	#return _active
#
#
#func play(path: TurnOrderPath) -> void:
	#if _active:
		#return
	#if !path or !path.is_valid():
		#return
	#if !_spark or !_label:
		#return
#
	#_active = true
	#show()
#
	#_kill_travel()
	#_kill_label_fade()
	#_clear_ordinals()
#
	#_spark.visible = true
	#_label.visible = true
#
	#_base_scale = _spark.scale
#
	## Lifted key points
	#var player_p := _lift(path.player_pos)
#
	## Lifted traversal lists (already in child/turn/spatial order)
	#var behind := _lift_positions(path.behind_friendlies)          # move left through these
	#var enemies := _lift_positions(path.enemies_front_to_back)     # move right through these
	#var in_front := _lift_positions(path.in_front_friendlies)      # move left through these (toward player)
#
	## Compute spacing from "first two fighters in child order"
	#var friendly_order: Array[Vector2] = []
	#friendly_order.append_array(_lift_positions(path.in_front_friendlies))
	#friendly_order.append(player_p)
	#friendly_order.append_array(_lift_positions(path.behind_friendlies))
#
	#var friendly_spacing := _compute_spacing_x(friendly_order, default_spacing)
	#var enemy_spacing := _compute_spacing_x(enemies, default_spacing)
#
	## WRAP ANCHORS:
	## - "front" fighter is index 0 (closest to center)
	## - when wrapping, blip to ONE spacing in front of that front fighter
	##   (friendlies: to the RIGHT; enemies: to the LEFT)
	#var friendly_front := player_p
	#if !in_front.is_empty():
		#friendly_front = in_front[0]
#
	#var has_enemy_front := !enemies.is_empty()
	#var enemy_front := Vector2.ZERO
	#if has_enemy_front:
		#enemy_front = enemies[0]
#
	#var friendly_wrap_anchor := friendly_front + Vector2(+friendly_spacing, 0.0) # right of friendly front
	#var enemy_wrap_anchor := enemy_front + Vector2(-enemy_spacing, 0.0)          # left of enemy front
#
	## Reset presentation
	#_spark.global_position = player_p
	#_spark.scale = _base_scale
	#_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, 0.0)
	#
	## Label: place ONCE (does not move), then fade later
	#_place_label_once_at_spark()
	#_label.modulate.a = 0.0
	#_start_label_fade_in()
#
	#_travel = get_tree().create_tween()
	#_travel.set_trans(Tween.TRANS_LINEAR)
	#_travel.set_ease(Tween.EASE_IN_OUT) # ignored-ish by linear
#
	## --- Intro: alpha-in + linger ---
	#_travel.tween_property(_spark, "modulate:a", ghost_alpha, maxf(intro_grow_duration, 0.01))
	#_travel.tween_interval(maxf(intro_linger, 0.0))
#
#
	## Start moving: label fade starts exactly here; spark returns to base scale
	#_travel.tween_callback(func():
		#if !_active:
			#return
		#_start_label_fade()
	#)
#
	## Ordinals start at 1
	#var ordinal_ref := [1]
#
	## ============================================================
	## A) player -> leftward through rear allies (behind)
	## ============================================================
	#_append_traverse(_travel, behind, ordinal_ref)
#
	## Leave friendly group one more spacing LEFT for one full interval
	#var last_friendly := player_p if behind.is_empty() else behind[behind.size() - 1]
	#_append_move(_travel, last_friendly + Vector2(-friendly_spacing, 0.0), _tb())
#
	## [instant] blip to "in front of enemies" (one spacing LEFT of enemy front)
	## If no enemies, just blip to the friendly wrap anchor so it doesn't jump to (0,0)
	#_append_move(_travel, (enemy_wrap_anchor if has_enemy_front else friendly_wrap_anchor), _blip())
#
	## ============================================================
	## B) approach -> rightward through enemies
	## ============================================================
	#if has_enemy_front:
		#_append_move(_travel, enemies[0], _tb())
		#_append_pass_event(_travel, ordinal_ref)
		#for i in range(1, enemies.size()):
			#_append_move(_travel, enemies[i], _tb())
			#_append_pass_event(_travel, ordinal_ref)
#
	## Leave enemy group one more spacing RIGHT for one full interval
	#var last_enemy := enemy_wrap_anchor if enemies.is_empty() else enemies[enemies.size() - 1]
	#_append_move(_travel, last_enemy + Vector2(+enemy_spacing, 0.0), _tb())
#
	## [instant] blip to "in front of friendlies" (one spacing RIGHT of friendly front)
	#_append_move(_travel, friendly_wrap_anchor, _blip())
#
	## ============================================================
	## C) approach -> leftward back via in-front friendlies -> player
	## ============================================================
	#if !in_front.is_empty():
		#_append_move(_travel, in_front[0], _tb())
		#_append_pass_event(_travel, ordinal_ref)
		#for i in range(1, in_front.size()):
			#_append_move(_travel, in_front[i], _tb())
			#_append_pass_event(_travel, ordinal_ref)
		#_append_move(_travel, player_p, _tb())
	#else:
		#_append_move(_travel, player_p, _tb())
#
	## Finish: fade spark, then fade all numbers at once
	#_travel.tween_callback(func():
		#if !_active:
			#return
		#_finish_fade_and_numbers()
	#)
#
#
#func cancel() -> void:
	#if !_active:
		#return
	#_cleanup()
	#canceled.emit()
#
#
## ------------------------------------------------------------
## Label placement + fade (label does NOT move)
## ------------------------------------------------------------
#
#
#func _start_label_fade_in() -> void:
	#_kill_label_fade()
	#_label_fade = get_tree().create_tween()
	#_label_fade.set_trans(Tween.TRANS_LINEAR)
	#_label_fade.set_ease(Tween.EASE_IN_OUT)
	#_label_fade.tween_property(_label, "modulate:a", ghost_alpha, maxf(intro_grow_duration, 0.01))
#
#
#func _place_label_once_at_spark() -> void:
	#_label.global_position = _spark.global_position
	#_label.global_position -= _label.size * 0.5
#
#
#func _start_label_fade() -> void:
	#_kill_label_fade()
	#_label_fade = get_tree().create_tween()
	#_label_fade.set_trans(Tween.TRANS_LINEAR)
	#_label_fade.set_ease(Tween.EASE_IN_OUT)
	#_label_fade.tween_property(_label, "modulate:a", 0.0, maxf(intro_label_fade, 0.01))
#
#
## ------------------------------------------------------------
## Travel helpers (reduce repetition)
## ------------------------------------------------------------
#
#func _append_traverse(t: Tween, pts: Array[Vector2], ordinal_ref: Array) -> void:
	#for p in pts:
		#_append_move(t, p, _tb())
		#_append_pass_event(t, ordinal_ref)
#
#func _append_move(t: Tween, target: Vector2, duration: float) -> void:
	#t.tween_property(_spark, "global_position", target, maxf(duration, 0.001))
#
#func _append_pass_event(t: Tween, ordinal_ref: Array) -> void:
	#t.tween_callback(func():
		#if !_active:
			#return
		#_spawn_preview_number(ordinal_ref[0])
		#ordinal_ref[0] += 1
		#_scale_bump_only()
	#)
#
#func _compute_spacing_x(arr: Array[Vector2], fallback: float) -> float:
	#if arr.size() < 2:
		#return fallback
	#var dx := absf(arr[1].x - arr[0].x)
	#return fallback if dx <= 0.01 else dx
#
#func _tb() -> float:
	#return maxf(time_between_fighters, 0.01)
#
#func _blip() -> float:
	#return maxf(blip_duration, 0.001)
#
#
## ------------------------------------------------------------
## Preview numbers + pulse (scale bump only)
## ------------------------------------------------------------
#
#func _spawn_preview_number(n: int) -> void:
	#if !turn_preview_number_scn or !ordinals_parent:
		#return
#
	#var node := turn_preview_number_scn.instantiate() as TurnPreviewNumber
	#if !node:
		#return
#
	#ordinals_parent.add_child(node)
#
	## Decouple from parent transform so global_position is stable
	#node.set_as_top_level(true)
	#node.global_position = _spark.global_position
#
	#node.set_ordinal(n)
#
#func _scale_bump_only() -> void:
	#var half := maxf(pulse_total_time * 0.5, 0.01)
	#var t := get_tree().create_tween()
	#t.set_trans(Tween.TRANS_LINEAR)
	#t.set_ease(Tween.EASE_IN_OUT)
	#t.tween_property(_spark, "scale", _base_scale * pulse_scale_mult, half)
	#t.tween_property(_spark, "scale", _base_scale, half)
#
#
## ------------------------------------------------------------
## Finish / lifecycle
## ------------------------------------------------------------
#
#func _finish_fade_and_numbers() -> void:
	#_kill_travel()
	#_travel = get_tree().create_tween()
	#_travel.set_trans(Tween.TRANS_LINEAR)
	#_travel.set_ease(Tween.EASE_IN_OUT)
#
	#_travel.tween_property(_spark, "modulate:a", 0.0, maxf(fade_out_duration, 0.01))
#
	#_travel.tween_callback(func():
		#_fade_all_ordinals()
	#)
#
	## Wait for TurnPreviewNumber.fade_out() duration
	#_travel.tween_interval(TurnPreviewNumber.FADE_TIME)
#
	#_travel.tween_callback(func():
		#_cleanup()
		#finished.emit()
	#)
#
#func _fade_all_ordinals() -> void:
	#if !ordinals_parent:
		#return
	#for child in ordinals_parent.get_children():
		#var n := child as TurnPreviewNumber
		#if n and is_instance_valid(n):
			#n.fade_out()
#
#func _cleanup() -> void:
	#_kill_travel()
	#_kill_label_fade()
	#_clear_ordinals()
	#_active = false
#
	## Do not hide() if your ordinals are top-level (they won't inherit),
	## but keeping controller visible/hidden doesn't matter much either way.
	## hide()
#
	#if _spark and is_instance_valid(_spark):
		#_spark.visible = false
		#_spark.scale = _base_scale
		#_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, 0.0)
#
	#if _label and is_instance_valid(_label):
		#_label.visible = false
		#_label.modulate.a = 0.0
#
#func _clear_ordinals() -> void:
	## New play() should not inherit prior run's ordinals.
	## These are top-level; freeing them is safe.
	#if !ordinals_parent:
		#return
	#for child in ordinals_parent.get_children():
		#if child and is_instance_valid(child):
			#child.queue_free()
#
#func _kill_travel() -> void:
	#if _travel and is_instance_valid(_travel):
		#_travel.kill()
	#_travel = null
#
#func _kill_label_fade() -> void:
	#if _label_fade and is_instance_valid(_label_fade):
		#_label_fade.kill()
	#_label_fade = null
#
#
## ------------------------------------------------------------
## Position
## ------------------------------------------------------------
#
#func _lift(p: Vector2) -> Vector2:
	#return p + Vector2(0.0, -height_above_feet)
#
#func _lift_positions(arr: Array[Vector2]) -> Array[Vector2]:
	#var out: Array[Vector2] = []
	#out.resize(arr.size())
	#for i in range(arr.size()):
		#out[i] = _lift(arr[i])
	#return out
