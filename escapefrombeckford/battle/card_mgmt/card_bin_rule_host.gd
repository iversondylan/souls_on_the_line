class_name CardBinRuleHost extends RefCounted

var player_turn_refill_amount: int = 3
var player_turn_refill_use_soulbound_guarantee: bool = true

var player_end_cleanup_should_discard_hand: bool = true
var player_end_cleanup_should_exhaust_hand: bool = false
var player_end_cleanup_cards_to_keep: Array[String] = []


func build_player_turn_refill_context(source_id: int) -> DrawContext:
	var ctx := DrawContext.new()
	ctx.source_id = int(source_id)
	ctx.amount = maxi(int(player_turn_refill_amount), 0)
	ctx.reason = "player_turn_refill"
	ctx.phase = "player_turn_start"
	ctx.use_soulbound_guarantee = bool(player_turn_refill_use_soulbound_guarantee)
	return ctx


func build_player_end_cleanup_context(source_id: int) -> HandCleanupContext:
	var ctx := HandCleanupContext.new()
	ctx.source_id = int(source_id)
	ctx.cleanup_kind = "player_end_turn"
	ctx.phase = "player_turn_end"
	ctx.reason = "player_end_cleanup"
	ctx.should_discard_hand = bool(player_end_cleanup_should_discard_hand)
	ctx.should_exhaust_hand = bool(player_end_cleanup_should_exhaust_hand)
	ctx.cards_to_keep = player_end_cleanup_cards_to_keep.duplicate()
	return ctx


func prepare_draw(_ctx: DrawContext) -> void:
	return


func after_draw(_ctx: DrawContext) -> void:
	return


func prepare_discard(_ctx: DiscardContext) -> void:
	return


func after_discard(_ctx: DiscardContext) -> void:
	return


func prepare_hand_cleanup(_ctx: HandCleanupContext) -> void:
	return


func after_hand_cleanup(_ctx: HandCleanupContext) -> void:
	return
