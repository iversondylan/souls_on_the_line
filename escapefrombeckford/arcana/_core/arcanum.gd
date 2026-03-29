# arcanum.gd

class_name Arcanum extends Resource

enum Type {START_OF_TURN, START_OF_COMBAT, END_OF_TURN, END_OF_COMBAT, EVENT_BASED}
enum Beats {NONE, IN, OUT, IN_OUT}
@export var arcanum_name: String
@export var type: Type
@export var starter_arcanum: bool = false
@export var icon: Texture
@export_multiline var tooltip_description: String
@export_multiline var flavor_text: String
@export_multiline var lore: String

# Legacy convenience for older live/run-only paths.
# Battle sim should not depend on this mutable reference.
var arcanum_display: ArcanumDisplay

func get_id() -> StringName:
	return &""

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

func on_targeting_retarget(_api: SimBattleAPI, _targeting_ctx: TargetingContext) -> void:
	pass

func on_targeting_interpose(_api: SimBattleAPI, _targeting_ctx: TargetingContext) -> void:
	pass

func get_modifier_tokens_for(_target: Node) -> Array[ModifierToken]:
	return []

func contributes_modifier() -> bool:
	return false

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return []

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
