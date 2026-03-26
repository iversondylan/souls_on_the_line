# discard_effect.gd

class_name DiscardEffect extends Effect

var amount: int = 1
var source_id: int = 0
var reason: String = ""

func execute(_api: SimBattleAPI) -> void:
	var ctx := DiscardContext.new()
	ctx.source_id = source_id
	ctx.amount = amount
	ctx.reason = reason
	Events.request_discard_cards.emit(ctx)
