# resource_state.gd

class_name ResourceState extends RefCounted

var mana: int = 0
var max_mana: int = 0

var pending_discard: DiscardRequest = null


func clone() -> ResourceState:
	var r := ResourceState.new()
	r.mana = int(mana)
	r.max_mana = int(max_mana)

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
