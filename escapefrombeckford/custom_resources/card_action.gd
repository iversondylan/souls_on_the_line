class_name CardAction extends Resource

#var card_data: CardData
#var battle_scene: BattleScene
#var player: Player

enum ActionType {
	MELEE_ATTACK,
	DAMAGE,
	BLOCK,
	MOVE,
	STATUS,
	SUMMON
}

@export var action_type: ActionType

@export var requires_enemy: bool = false
@export var requires_summon_slot: bool = false
@export var requires_target: bool = true

func activate(_ctx: CardActionContext) -> bool:
	push_error("Must override CardAction.activate()")
	return false

func is_playable(ctx: CardActionContext) -> bool:
	return ctx.player.can_play_card(ctx.card_data)

#enum TargetType {
	#SELF,
	#BATTLEFIELD,
	#ALLY_OR_SELF,
	#ALLY,
	#SINGLE_ENEMY,
	#ALL_ENEMIES,
	#EVERYONE
#}

func get_preview_source_fighter(_player: Player, resolved: CardResolvedTarget) -> Fighter:
	return null if resolved.fighters.is_empty() else resolved.fighters[0]

func get_description(description: String, _target_enemy: Fighter = null) -> String:
	return description

func get_unmod_description(description: String) -> String:
	return get_description(description)
