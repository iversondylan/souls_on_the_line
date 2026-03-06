# status.gd

class_name Status extends Resource

signal status_applied(status: Status)
signal status_changed()

enum ProcType {START_OF_TURN, END_OF_TURN, EVENT_BASED}
enum NumberDisplayType {NONE, INTENSITY, DURATION}
enum ReapplyType {INTENSITY, DURATION, REPLACE, IGNORE}
enum ExpirationPolicy {
	DURATION,        # duration ticks down
	GROUP_TURN_START,  # expires at start of group turn
	GROUP_TURN_END,  # expires at end of group turn
	EVENT_OR_NEVER,  # expires when something external says so or permanent
}

@export_group("Status Data")

@export var proc_type: ProcType
@export var number_display_type: NumberDisplayType
@export var reapply_type: ReapplyType
@export var expiration_policy: ExpirationPolicy = ExpirationPolicy.EVENT_OR_NEVER
@export var duration: int : set = _set_duration
@export var intensity: int : set = _set_intensity

@export_group("Status Visuals")
@export var icon: Texture
@export_multiline var tooltip: String


#var id: String = ""
var status_parent: Fighter
#var battle_scene: BattleScene

func get_id() -> StringName:
	return ""

func init_status(_target: Node) -> void:
	pass

func apply_status(_target: Node) -> void:
	status_applied.emit(self)

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	return []

func contributes_modifier() -> bool:
	return false

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return []

func get_tooltip() -> String:
	return tooltip

func _set_duration(new_duration: int) -> void:
	duration = new_duration
	status_changed.emit()

func _set_intensity(new_intensity: int) -> void:
	intensity = new_intensity
	status_changed.emit()

func is_expired() -> bool:
	return expiration_policy == ExpirationPolicy.DURATION and duration <= 0

func affects_others() -> bool:
	return false

func on_removed() -> void:
	pass

func on_damage_taken(_ctx: DamageContext) -> void:
	pass

func affects_intent_legality() -> bool:
	return false

func on_death(_api: SimBattleAPI, _dead_id: int, _killer_id: int, _reason: String) -> void:
	pass

# -------------------------------------------------------------------
# Helpers so callers don't need separate functions for live vs sim
# -------------------------------------------------------------------

func make_token_ctx_node(owner_node: Node) -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	ctx.id = get_id()
	ctx.duration = duration
	ctx.intensity = intensity
	ctx.owner = owner_node
	ctx.owner_id = -1
	return ctx

func make_token_ctx_state(state, _owner_id: int) -> StatusTokenContext:
	# `state` can be a StatusState or Dictionary; keep it flexible.
	var ctx := StatusTokenContext.new()
	if state is Dictionary:
		ctx.id = str(state.get("id", ""))
		ctx.duration = int(state.get("duration", 0))
		ctx.intensity = int(state.get("intensity", 0))
	else:
		# assumes StatusState-like
		ctx.id = state.id
		ctx.duration = state.duration
		ctx.intensity = state.intensity
	ctx.owner = null
	ctx.owner_id = _owner_id
	return ctx

static func set_token_owner(token: ModifierToken, ctx: StatusTokenContext) -> void:
	if !token or !ctx:
		return
	token.owner = ctx.owner
	token.owner_id = ctx.owner_id
