# card_action_context_view.gd

class_name CardActionContextView extends RefCounted

var card_data: CardData
#var battle_scene: BattleScene
var battle_view: BattleView

var source_id: int = 0
var resolved: CardResolvedTargetView
