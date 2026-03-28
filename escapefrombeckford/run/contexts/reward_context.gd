# reward_context.gd
class_name RewardContext extends RefCounted

enum SourceKind {
	UNKNOWN,
	BATTLE,
	TREASURE,
}

var source_kind: int = SourceKind.UNKNOWN

var run_state: RunState
var player_data: PlayerData
var arcana_system: ArcanaSystem

var battle_data: BattleData = null

var gold_rewards: Array[int] = []
var include_card_reward: bool = false
var card_choices: Array[CardData] = []
var arcanum_rewards: Array[Arcanum] = []
var claimed_gold_indices: Array[int] = []
var card_reward_claimed: bool = false
var claimed_arcanum_indices: Array[int] = []
