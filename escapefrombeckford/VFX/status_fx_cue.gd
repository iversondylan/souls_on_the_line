class_name StatusFxCue
extends Resource

enum Phase {
	INTRO,
	SUSTAIN,
	OUTRO,
}

@export var phase: Phase = Phase.SUSTAIN
@export var fx_id: StringName = &""
@export var height_percent: float = 50.0
@export var offset: Vector2 = Vector2.ZERO
@export var scale: float = 1.0

@export_group("Sustain Only Parameters")
@export var delay_begin: float = 0.0
@export var ramp_duration_begin: float = 0.0
@export var ramp_alpha_begin: bool = false
@export var ramp_scale_begin: bool = false
@export var delay_end: float = 0.0
@export var ramp_duration_end: float = 0.0
@export var ramp_alpha_end: bool = false
@export var ramp_scale_end: bool = false


func matches(requested_phase: Phase) -> bool:
	return int(phase) == int(requested_phase)
