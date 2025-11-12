class_name CardData extends Resource

enum CardType {
	ATTACK,
	DEFEND,
	SUMMON,
	POWER,
	BUFF,
	DEBUFF,
	MOVEMENT
}

enum TargetType {
	SELF,
	BATTLEFIELD,
	ALLY_OR_SELF,
	ALLY,
	SINGLE_ENEMY,
	ALL_ENEMIES,
	EVERYONE
}

enum Rarity {COMMON, UNCOMMON, RARE}

enum CardStatus {
	PRE_GAME,
	DRAW_PILE,
	HAND,
	DISCARD_PILE,
	SUMMON_RESERVE,
	EXHAUSTED
}

const RARITY_COLORS := {
	CardData.Rarity.COMMON: Color.GRAY,
	CardData.Rarity.UNCOMMON: Color.ROYAL_BLUE,
	CardData.Rarity.RARE: Color.DARK_ORANGE,
}

@export_group("Card Attributes")
@export var id: int
@export var card_type: CardType
@export var target_type: TargetType
@export var rarity: Rarity
@export var name: String
@export var deplete: bool
@export_multiline var description: String
@export var cost_red: int
@export var cost_green: int
@export var cost_blue: int
@export var texture: Texture2D
@export var actions: Array[GDScript] = []
@export var sound: AudioStream

var card_status: CardStatus

func is_single_targeted() -> bool:
	return target_type == TargetType.SINGLE_ENEMY or target_type == TargetType.ALLY_OR_SELF or target_type == TargetType.ALLY or target_type == TargetType.BATTLEFIELD



func _get_targets(targets: Array[Node]) -> Array[Node]:
	if not targets:
		return []

	var tree := targets[0].get_tree()
	#Events.need_updated_game_state.emit()
	match target_type:
		TargetType.SELF:
			return tree.get_nodes_in_group("player")
		TargetType.BATTLEFIELD:
			return tree.get_nodes_in_group("battle_scene")
		TargetType.ALLY_OR_SELF:
			return tree.get_nodes_in_group("allies") + tree.get_nodes_in_group("player")
		#TargetType.ALLY:
			#for target in targets:
				#if target is Combatant:
					#if target.combatant_data.team == 1:
						#return [target]
			#return []
		#TargetType.SINGLE_ENEMY:
			#for target in targets:
				#if target is Combatant:
					#if target.combatant_data.team == 2:
						#return [target]
			#return []
		TargetType.ALL_ENEMIES:
			return tree.get_nodes_in_group("enemies")
		TargetType.EVERYONE:
			return tree.get_nodes_in_group("enemies") + tree.get_nodes_in_group("allies") + tree.get_nodes_in_group("player")
		_:
			return []
