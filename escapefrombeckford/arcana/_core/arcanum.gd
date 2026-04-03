# arcanum.gd

class_name Arcanum extends Resource

enum Type {PLAYER_TURN_BEGIN, BATTLE_START, PLAYER_TURN_END, BATTLE_END, EVENT_BASED}
enum Beats {NONE, IN, OUT, IN_OUT}

const START_OF_TURN := Type.PLAYER_TURN_BEGIN
const START_OF_COMBAT := Type.BATTLE_START
const END_OF_TURN := Type.PLAYER_TURN_END
const END_OF_COMBAT := Type.BATTLE_END

@export var arcanum_name: String
@export var type: Type
@export var starter_arcanum: bool = false
@export var icon: Texture
@export_multiline var tooltip_description: String
@export_multiline var flavor_text: String
@export_multiline var lore: String
@export var projected_statuses: Array[Status] = []

# Legacy convenience for older live/run-only paths.
# Battle sim should not depend on this mutable reference.
var arcanum_display: ArcanumDisplay

func get_id() -> StringName:
	return &""

func procs_on_battle_start() -> bool:
	return int(type) == int(Type.BATTLE_START)

func procs_on_player_turn_begin() -> bool:
	return int(type) == int(Type.PLAYER_TURN_BEGIN)

func procs_on_player_turn_end() -> bool:
	return int(type) == int(Type.PLAYER_TURN_END)

func procs_on_battle_end() -> bool:
	return int(type) == int(Type.BATTLE_END)

func seed_battle_entry(_entry: ArcanaState.ArcanumEntry) -> void:
	pass

func on_battle_start(ctx) -> void:
	on_battle_started(ctx.api if ctx != null else null)

func on_player_turn_begin(ctx) -> void:
	on_turn_started(ctx.api if ctx != null else null)

func on_player_turn_end(ctx) -> void:
	on_turn_ended(ctx.api if ctx != null else null)

func on_battle_end(ctx) -> void:
	on_battle_ended(ctx.api if ctx != null else null)

func on_actor_turn_begin(_ctx, _actor_id: int) -> void:
	pass

func on_actor_turn_end(_ctx, _actor_id: int) -> void:
	pass

func on_damage_will_be_taken(_ctx, _damage_ctx: DamageContext) -> void:
	pass

func on_damage_taken(_ctx, _damage_ctx: DamageContext) -> void:
	pass

func on_death(_ctx, _dead_id: int, _killer_id: int, _reason: String) -> void:
	pass

func on_battle_started(_api: SimBattleAPI) -> void:
	pass

func on_turn_started(_api: SimBattleAPI) -> void:
	pass

func on_turn_ended(_api: SimBattleAPI) -> void:
	pass

func on_battle_ended(_api: SimBattleAPI) -> void:
	pass

func on_reward_context_started(_ctx: RewardContext) -> void:
	pass

func on_shop_context_started(_ctx: ShopContext) -> void:
	pass

func get_targeting_priority(_stage: int) -> int:
	return 100

func on_targeting_retarget(_ctx, _targeting_ctx: TargetingContext) -> void:
	pass

func on_targeting_interpose(_ctx, _targeting_ctx: TargetingContext) -> void:
	pass

func get_modifier_tokens(_ctx, _target_id: int) -> Array[ModifierToken]:
	return []

func contributes_modifier() -> bool:
	return false

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	var out: Array[Modifier.Type] = []
	return out

func affects_others() -> bool:
	return !get_projected_statuses().is_empty()

func get_projected_statuses() -> Array[Status]:
	var out: Array[Status] = []
	for projected: Status in projected_statuses:
		if projected != null:
			out.append(projected)
	return out

func affects_target(state: BattleState, source_id: int, target_id: int) -> bool:
	if state == null or source_id <= 0 or target_id <= 0:
		return false

	var source := state.get_unit(source_id)
	var target := state.get_unit(target_id)
	if source == null or target == null:
		return false

	return int(source.team) == int(target.team)

func get_projection_intensity(ctx) -> int:
	if ctx == null:
		return 1
	return ctx.get_intensity(1)

func get_projection_duration(ctx) -> int:
	if ctx == null:
		return 0
	return ctx.get_duration(0)

func get_beats() -> int:
	return Beats.NONE

func wants_in_beat() -> bool:
	var b := int(get_beats())
	return b == Beats.IN or b == Beats.IN_OUT

func wants_out_beat() -> bool:
	var b := int(get_beats())
	return b == Beats.OUT or b == Beats.IN_OUT

# This method should be implemented by event-based arcana
# that connect to the Events bus to make sure that they
# are disconnected when an arcanum is removed.
func deactivate_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	pass

func initialize_arcanum(_arcanum_display: ArcanumDisplay) -> void:
	pass

func get_tooltip() -> String:
	return tooltip_description

func can_appear_as_reward(player: PlayerData) -> bool:
	if starter_arcanum:
		return false
	return player.possible_arcana.get_ids().has(get_id())
