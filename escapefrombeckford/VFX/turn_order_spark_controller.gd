# turn_order_spark_controller.gd
class_name TurnOrderSparkController
extends Node2D

signal finished
signal canceled

@export var height_above_feet: float = 140.0

# One knob for timing once it starts moving.
@export var time_between_fighters: float = 0.90

# Instant-ish blip (must be > 0 for tween consistency)
@export var blip_duration: float = 0.001

@export var default_spacing: float = 240.0

# --- INTRO / FEEL ---
@export var intro_grow_mult: float = 1.25
@export var intro_grow_duration: float = 0.55
@export var intro_linger: float = 0.90

# Label fades starting exactly when movement begins
@export var intro_label_fade: float = 0.90

# --- PASS PULSE (no pauses) ---
@export var pulse_scale_mult: float = 1.20
@export var pulse_total_time: float = 0.22
@export var pulse_orange_time: float = 0.10

# --- FINISH ---
@export var fade_out_duration: float = 0.75

@export var base_blue: Color = Color(0.45, 0.75, 1.0, 1.0)
@export var flash_orange: Color = Color(1.0, 0.65, 0.25, 1.0)
@export var ghost_alpha: float = 0.95

@onready var _label: RichTextLabel = $SparkLabel
@onready var _spark: Sprite2D = $Spark

var _active := false

# Separate tweens:
var _travel: Tween
var _label_fade: Tween

var _base_scale: Vector2 = Vector2.ONE
var _pulse_seq: int = 0


func _ready() -> void:
	hide()
	if _spark:
		_base_scale = _spark.scale
		_spark.modulate.a = 0.0
	if _label:
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
	_pulse_seq += 1
	
	_base_scale = _spark.scale
	
	# Lifted key points
	var player_p := _lift(path.player_pos)
	
	# Lifted traversal lists (already in child/turn/spatial order)
	var behind := _lift_positions(path.behind_friendlies)          # move left through these
	var enemies := _lift_positions(path.enemies_front_to_back)     # move right through these
	var in_front := _lift_positions(path.in_front_friendlies)      # move left through these (toward player)
	
	# Compute spacing from "first two fighters in child order"
	var friendly_order: Array[Vector2] = []
	friendly_order.append_array(_lift_positions(path.in_front_friendlies))
	friendly_order.append(player_p)
	friendly_order.append_array(_lift_positions(path.behind_friendlies))
	
	var friendly_spacing := _compute_spacing_x(friendly_order, default_spacing)
	var enemy_spacing := _compute_spacing_x(enemies, default_spacing)
	
	# WRAP ANCHORS:
	# - "front" fighter is index 0 (closest to center)
	# - when wrapping, blip to ONE spacing in front of that front fighter
	#   (friendlies: to the RIGHT; enemies: to the LEFT)
	var friendly_front := player_p
	if !in_front.is_empty():
		friendly_front = in_front[0]
	# If you ever want "front of friendlies" to be the closest friendly overall, you could:
	# friendly_front = (in_front[0] if !in_front.is_empty() else player_p)
	
	var enemy_front := Vector2.ZERO
	var has_enemy_front := !enemies.is_empty()
	if has_enemy_front:
		enemy_front = enemies[0]
	
	var friendly_wrap_anchor := friendly_front + Vector2(+friendly_spacing, 0.0) # right of friendly front
	var enemy_wrap_anchor := enemy_front + Vector2(-enemy_spacing, 0.0)          # left of enemy front
	
	# Reset presentation
	_spark.global_position = player_p
	_spark.scale = _base_scale
	_spark.modulate = Color(flash_orange.r, flash_orange.g, flash_orange.b, ghost_alpha)
	
	# Label: place ONCE (does not move), then fade later
	_label.modulate.a = 1.0
	_place_label_once_at_spark()
	
	_travel = get_tree().create_tween()
	_travel.set_trans(Tween.TRANS_LINEAR)
	_travel.set_ease(Tween.EASE_IN_OUT) # ignored-ish by linear
	
	# --- Intro: orange grow + linger ---
	_travel.tween_property(_spark, "scale", _base_scale * intro_grow_mult, maxf(intro_grow_duration, 0.01))
	_travel.tween_interval(maxf(intro_linger, 0.0))
	
	# Start moving: (1) start label fade tween (2) turn spark blue (no pulse leaving player)
	_travel.tween_callback(func():
		if !_active:
			return
		_start_label_fade() # fades label in place
		_spark.scale = _base_scale
		_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, ghost_alpha)
	)
	
	# ============================================================
	# A) player -> leftward through rear allies (behind)
	# ============================================================
	_append_points_with_pass_pulse(_travel, behind)
	
	# Leave friendly group one more spacing LEFT for one full interval
	var last_friendly := player_p if behind.is_empty() else behind[behind.size() - 1]
	var friendly_leave := last_friendly + Vector2(-friendly_spacing, 0.0)
	_travel.tween_property(_spark, "global_position", friendly_leave, _tb())
	
	# [instant] blip to "in front of enemies" (one spacing LEFT of enemy front)
	if has_enemy_front:
		_travel.tween_property(_spark, "global_position", enemy_wrap_anchor, _blip())
	else:
		# no enemies: just blip back to friendly anchor so it doesn't jump to (0,0)
		_travel.tween_property(_spark, "global_position", friendly_wrap_anchor, _blip())
	
	# ============================================================
	# B) approach -> rightward through enemies
	# We are currently sitting one spacing LEFT of enemy front.
	# Take one full interval to reach the first enemy, then pulse.
	# ============================================================
	if has_enemy_front:
		_travel.tween_property(_spark, "global_position", enemies[0], _tb())
		_travel.tween_callback(func():
			if !_active: return
			_start_pass_pulse()
		)
	
		for i in range(1, enemies.size()):
			_travel.tween_property(_spark, "global_position", enemies[i], _tb())
			_travel.tween_callback(func():
				if !_active: return
				_start_pass_pulse()
			)
	
	# Leave enemy group one more spacing RIGHT for one full interval
	var last_enemy := enemy_wrap_anchor if enemies.is_empty() else enemies[enemies.size() - 1]
	var enemy_leave := last_enemy + Vector2(+enemy_spacing, 0.0)
	_travel.tween_property(_spark, "global_position", enemy_leave, _tb())
	
	# [instant] blip to "in front of friendlies" (one spacing RIGHT of friendly front)
	_travel.tween_property(_spark, "global_position", friendly_wrap_anchor, _blip())
	
	# ============================================================
	# C) approach -> leftward back via in-front friendlies -> player
	# We are currently sitting one spacing RIGHT of friendly front.
	# Take one full interval to reach first in_front (or player), then pulse.
	# ============================================================
	if !in_front.is_empty():
		_travel.tween_property(_spark, "global_position", in_front[0], _tb())
		_travel.tween_callback(func():
			if !_active: return
			_start_pass_pulse()
		)
	
		for i in range(1, in_front.size()):
			_travel.tween_property(_spark, "global_position", in_front[i], _tb())
			_travel.tween_callback(func():
				if !_active: return
				_start_pass_pulse()
			)
	
		_travel.tween_property(_spark, "global_position", player_p, _tb())
	else:
		# If no in-front friendlies, go from friendly anchor to player in one interval.
		_travel.tween_property(_spark, "global_position", player_p, _tb())
	
	# Finish
	_travel.tween_callback(func():
		if !_active: return
		_finish_fade()
	)


func cancel() -> void:
	if !_active:
		return
	_cleanup()
	canceled.emit()


# ------------------------------------------------------------
# Label placement + fade (label does NOT follow spark)
# ------------------------------------------------------------

func _place_label_once_at_spark() -> void:
	if !_label or !_spark:
		return
	_label.global_position = _spark.global_position
	_label.global_position -= _label.size * 0.5


func _start_label_fade() -> void:
	if !_label or !_active:
		return
	_kill_label_fade()
	_label_fade = get_tree().create_tween()
	_label_fade.set_trans(Tween.TRANS_LINEAR)
	_label_fade.set_ease(Tween.EASE_IN_OUT)
	_label_fade.tween_property(_label, "modulate:a", 0.0, maxf(intro_label_fade, 0.01))


# ------------------------------------------------------------
# Travel helpers
# ------------------------------------------------------------

func _append_points_with_pass_pulse(t: Tween, pts: Array[Vector2]) -> void:
	for p in pts:
		t.tween_property(_spark, "global_position", p, _tb())
		t.tween_callback(func():
			if !_active: return
			_start_pass_pulse()
		)

func _compute_spacing_x(arr: Array[Vector2], fallback: float) -> float:
	if arr.size() < 2:
		return fallback
	var dx := absf(arr[1].x - arr[0].x)
	return fallback if dx <= 0.01 else dx

func _tb() -> float:
	return maxf(time_between_fighters, 0.01)

func _blip() -> float:
	return maxf(blip_duration, 0.001)


# ------------------------------------------------------------
# Pulse (runs alongside travel; does not pause it)
# ------------------------------------------------------------

func _start_pass_pulse() -> void:
	if !_active or !_spark:
		return
	
	_pulse_seq += 1
	var my_seq := _pulse_seq
	
	# Flash orange immediately
	_spark.modulate = Color(flash_orange.r, flash_orange.g, flash_orange.b, ghost_alpha)
	
	# Scale bump relative to original sprite scale
	var half := maxf(pulse_total_time * 0.5, 0.01)
	
	var t := get_tree().create_tween()
	t.set_trans(Tween.TRANS_LINEAR)
	t.set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_spark, "scale", _base_scale * pulse_scale_mult, half)
	t.tween_property(_spark, "scale", _base_scale, half)
	
	# Return to blue after a short window; ignore stale pulses
	get_tree().create_timer(maxf(pulse_orange_time, 0.01), false).timeout.connect(func():
		if !_active or !_spark:
			return
		if my_seq != _pulse_seq:
			return
		_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, ghost_alpha)
	)


# ------------------------------------------------------------
# Finish / lifecycle
# ------------------------------------------------------------

func _finish_fade() -> void:
	_kill_travel()
	_travel = get_tree().create_tween()
	_travel.set_trans(Tween.TRANS_LINEAR)
	_travel.set_ease(Tween.EASE_IN_OUT)
	_travel.tween_property(_spark, "modulate:a", 0.0, maxf(fade_out_duration, 0.01))
	_travel.tween_callback(func():
		_cleanup()
		finished.emit()
	)

func _cleanup() -> void:
	_kill_travel()
	_kill_label_fade()
	_active = false
	hide()
	_pulse_seq += 1
	
	if _spark and is_instance_valid(_spark):
		_spark.scale = _base_scale
		_spark.modulate = Color(base_blue.r, base_blue.g, base_blue.b, 0.0)
	if _label and is_instance_valid(_label):
		_label.modulate.a = 0.0

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
