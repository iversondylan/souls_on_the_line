# discard_effect.gd

class_name DiscardEffect extends Effect

var amount: int = 1
var source: Fighter
var reason: String = ""

func execute(_api: BattleAPI) -> void:
	var ctx := DiscardContext.new()
	ctx.source = source
	ctx.amount = amount
	ctx.reason = reason
	Events.request_discard_cards.emit(ctx)
