class_name ActionFxCue
extends Resource

enum Type {
	MELEE_WINDUP,
	MELEE_STRIKE_FOLLOWTHROUGH,
	MELEE_IMPACT,
	RANGED_STRIKE_WINDUP,
	RANGED_STRIKE_FIRE,
	RANGED_IMPACT,
	SUMMON_WINDUP,
	SUMMON_POP,
	STATUS_WINDUP_START,
	STATUS_POP,
	MOVE_WINDUP_START,
	MOVE_FOLLOWTHROUGH,
	HEAL_WINDUP_START,
	HEAL_POP,
	GENERIC_WINDUP_START,
	GENERIC_FOLLOWTHROUGH_START,
}

enum Anchor {
	ACTOR,
	TARGET,
}

enum SelectionMode {
	FIRST,
	ALTERNATE_BY_STRIKE_INDEX,
}

enum PlaybackMode {
	ONE_SHOT,
	PROJECTILE,
}

@export var type: Type = Type.MELEE_STRIKE_FOLLOWTHROUGH
@export var playback_mode: PlaybackMode = PlaybackMode.ONE_SHOT
@export var anchor: Anchor = Anchor.TARGET
@export var fx_ids: Array[StringName] = []
@export var selection_mode: SelectionMode = SelectionMode.FIRST
@export var offset: Vector2 = Vector2.ZERO
@export var scale: float = 1.0
@export_range(0.0, 1.0, 0.01) var center_y_ratio: float = 0.5
@export var mirror_offset_x_by_group_facing: bool = true
@export var mirror_fx_x_by_group_facing: bool = true
@export var random_rotation: bool = false

func matches(requested_type: Type) -> bool:
	return int(type) == int(requested_type)

func resolve_fx_id(strike_index: int = 0) -> StringName:
	if fx_ids.is_empty():
		return &""
	match int(selection_mode):
		SelectionMode.ALTERNATE_BY_STRIKE_INDEX:
			return fx_ids[abs(strike_index) % fx_ids.size()]
		_:
			return fx_ids[0]
