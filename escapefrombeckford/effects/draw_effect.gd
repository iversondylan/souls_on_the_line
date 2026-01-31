# card_draw_effect.gd

class_name CardDrawEffect extends Effect

var amount: int = 1
var source: Fighter
var reason: String = ""

func execute() -> void:
	var ctx := DrawContext.new()
	ctx.source = source
	ctx.amount = amount
	ctx.reason = reason
	Events.request_draw_cards.emit(ctx)
