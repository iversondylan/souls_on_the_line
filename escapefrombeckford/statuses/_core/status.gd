# status.gd

class_name Status extends Resource

signal status_applied(status: Status)
signal status_changed()

enum ProcType { START_OF_TURN, END_OF_TURN, EVENT_BASED }
enum NumberDisplayType { NONE, INTENSITY, DURATION }
enum ReapplyType { INTENSITY, DURATION, REPLACE, IGNORE }
enum ExpirationPolicy {
	DURATION,
	GROUP_TURN_START,
	GROUP_TURN_END,
	EVENT_OR_NEVER,
	PLAYER_TURN_START,
}
enum OP { APPLY, REMOVE, CHANGE }

@export_group("Status Data")
@export var status_name: String = ""
@export var proc_type: ProcType
@export var number_display_type: NumberDisplayType
@export var reapply_type: ReapplyType
@export var expiration_policy: ExpirationPolicy = ExpirationPolicy.EVENT_OR_NEVER

@export_group("Status Visuals")
@export var icon: Texture
@export_multiline var tooltip: String

var status_parent: CombatantView


# -------------------------------------------------------------------
# Identity
# -------------------------------------------------------------------

func get_id() -> StringName:
	return &""

# -------------------------------------------------------------------
# Hooks
# -------------------------------------------------------------------

func on_apply(_ctx: SimStatusContext, _apply_ctx: StatusContext) -> void:
	pass

func on_remove(_ctx: SimStatusContext, _remove_ctx: StatusContext) -> void:
	pass

func on_actor_turn_begin(_ctx: SimStatusContext) -> void:
	pass

func on_actor_turn_end(_ctx: SimStatusContext) -> void:
	pass

func on_group_turn_begin(_ctx: SimStatusContext, _acting_group_index: int) -> void:
	pass

func on_player_turn_begin(_ctx: SimStatusContext, _player_id: int) -> void:
	pass

func on_group_turn_end(_ctx: SimStatusContext, _ending_group_index: int) -> void:
	pass

func on_damage_taken(_ctx: SimStatusContext, _damage_ctx: DamageContext) -> void:
	pass

func on_damage_will_be_taken(_ctx: SimStatusContext, _damage_ctx: DamageContext) -> void:
	pass

func on_death(_ctx: SimStatusContext, _dead_id: int, _killer_id: int, _reason: String) -> void:
	pass

func get_targeting_priority(_stage: int) -> int:
	return 100

func on_targeting_retarget(_ctx: SimStatusContext, _targeting_ctx: TargetingContext) -> void:
	pass

func on_targeting_interpose(_ctx: SimStatusContext, _targeting_ctx: TargetingContext) -> void:
	pass

func grants_attack_spillthrough(_ctx: SimStatusContext) -> bool:
	return false

func grants_received_spillthrough(_ctx: SimStatusContext) -> bool:
	return false


# -------------------------------------------------------------------
# Modifier hooks
# -------------------------------------------------------------------

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	return []

func contributes_modifier() -> bool:
	return false

func affects_others() -> bool:
	return false

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return []

func get_max_intensity() -> int:
	return 0


# -------------------------------------------------------------------
# Query helpers
# -------------------------------------------------------------------

func get_tooltip(_intensity: int = 0, _duration: int = 0) -> String:
	return tooltip

func get_tooltip_sim(ctx: SimStatusContext) -> String:
	if ctx == null or !ctx.is_valid():
		return get_tooltip()
	return get_tooltip(ctx.get_intensity(), ctx.get_duration())

func affects_intent_legality() -> bool:
	return false

# -------------------------------------------------------------------
# Helpers
# -------------------------------------------------------------------

func make_token_ctx_state(state_like, _owner_id: int) -> StatusTokenContext:
	var ctx := StatusTokenContext.new()
	if state_like is Dictionary:
		ctx.id = StringName(state_like.get("id", ""))
		ctx.duration = int(state_like.get("duration", 0))
		ctx.intensity = int(state_like.get("intensity", 0))
		ctx.pending = bool(state_like.get("pending", false))
	else:
		ctx.id = state_like.id
		ctx.duration = state_like.duration
		ctx.intensity = state_like.intensity
		if "pending" in state_like:
			ctx.pending = bool(state_like.pending)
	ctx.owner = null
	ctx.owner_id = _owner_id
	return ctx

static func set_token_owner(token: ModifierToken, ctx: StatusTokenContext) -> void:
	if !token or !ctx:
		return
	token.owner = ctx.owner
	token.owner_id = ctx.owner_id
