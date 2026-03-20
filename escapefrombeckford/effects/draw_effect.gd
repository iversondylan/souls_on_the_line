# draw_effect.gd

class_name CardDrawEffect extends Effect

var amount: int = 1
var source: int = -1
var reason: String = ""

func execute(_api: SimBattleAPI) -> void:
	var ctx := DrawContext.new()
	ctx.source_id = source
	ctx.amount = amount
	ctx.reason = reason
	Events.request_draw_cards.emit(ctx)
