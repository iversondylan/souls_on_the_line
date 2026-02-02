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


# --- INTRO / FEEL ---
@export var intro_grow_duration: float = 0.55
@export var intro_linger: float = 0.35

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
