# status.gd

class_name Status extends Resource

signal status_applied(status: Status)
signal status_changed()

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
@export var number_display_type: NumberDisplayType
@export var reapply_type: ReapplyType
@export var expiration_policy: ExpirationPolicy = ExpirationPolicy.EVENT_OR_NEVER
@export var transformer_priority: int = 1

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

func on_attack_will_run(_ctx: SimStatusContext, _attack_ctx: AttackContext) -> void:
	pass

func on_strike_resolved(
	_ctx: SimStatusContext,
	_attack_ctx: AttackContext,
	_strike_index: int,
	_target_ids: Array[int]
) -> void:
	pass

func on_summon_will_resolve(
	_ctx: SimStatusContext,
	_summon_ctx: SummonContext,
	_summoned: CombatantState
) -> void:
	pass

func on_card_played(_ctx: SimStatusContext, _source_id: int, _card: CardData) -> void:
	pass

func should_skip_npc_action(_ctx: SimStatusContext) -> bool:
	return false

func on_removal(_ctx: SimStatusContext, _removal_ctx) -> void:
	pass

func listens_for_player_turn_begin() -> bool:
	return false


func listens_for_group_turn_begin() -> bool:
	return false


func listens_for_group_turn_end() -> bool:
	return false


func listens_for_any_death() -> bool:
	return false

func on_any_death(_ctx: SimStatusContext, _removal_ctx: RemovalContext) -> void:
	pass

func listens_for_targeting_retarget() -> bool:
	return false


func listens_for_targeting_interpose() -> bool:
	return false


func listens_for_card_played() -> bool:
	return false


func get_targeting_priority(_stage: int) -> int:
	return 100

func on_targeting_retarget(_ctx: SimStatusContext, _targeting_ctx: TargetingContext) -> void:
	pass

func on_targeting_interpose(_ctx: SimStatusContext, _targeting_ctx: TargetingContext) -> void:
	pass

func grants_attack_cleave(_ctx: SimStatusContext) -> bool:
	return false

func grants_received_cleave(_ctx: SimStatusContext) -> bool:
	return false

func get_attack_self_damage_on_strike(_ctx: SimStatusContext, _attack_ctx: AttackContext) -> int:
	return 0


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

func affects_card_cost() -> bool:
	return false

func get_card_cost_discount(_ctx: SimStatusContext, _card: CardData) -> int:
	return 0

func consume_on_card_play(_ctx: SimStatusContext, _card: CardData) -> bool:
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
