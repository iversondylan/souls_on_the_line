# resource_state.gd

class_name ResourceState extends RefCounted

enum HandMode {
	KEEP,
	DISCARD,
}

enum ShuffleMode {
	NORMAL,
	NO_SHUFFLE,
}

var mana: int = 0
# max_mana is the friendly-turn reset target, not a hard cap on current mana.
var max_mana: int = 0
var player_turn_draw_amount: int = 3
var player_turn_use_soulbound_guarantee: bool = true
var hand_mode: int = HandMode.DISCARD
var shuffle_mode: int = ShuffleMode.NORMAL

var pending_discard: DiscardRequest = null


func clone() -> ResourceState:
	var r := ResourceState.new()
	r.mana = int(mana)
	r.max_mana = int(max_mana)
	r.player_turn_draw_amount = int(player_turn_draw_amount)
	r.player_turn_use_soulbound_guarantee = bool(player_turn_use_soulbound_guarantee)
	r.hand_mode = int(hand_mode)
	r.shuffle_mode = int(shuffle_mode)

	if pending_discard != null:
		# If DiscardRequest is RefCounted/custom class without clone(),
		# copy fields manually.
		var req := DiscardRequest.new()
		req.request_id = int(pending_discard.request_id)
		req.source_id = int(pending_discard.source_id)
		req.amount = int(pending_discard.amount)
		req.reason = String(pending_discard.reason)
		req.card_uid = String(pending_discard.card_uid)
		r.pending_discard = req

	return r
