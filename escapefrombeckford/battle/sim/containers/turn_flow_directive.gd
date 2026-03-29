class_name TurnFlowDirective extends RefCounted

enum Kind {
	IDLE,
	BLOCKED,
	REQUEST_PLAYER_BEGIN,
	REQUEST_ARCANA,
	REQUEST_ACTOR,
	GROUP_TURN_ENDED,
}

var kind: int = Kind.IDLE
var actor_id: int = 0
var group_index: int = -1
var arcana_proc: int = -1


static func idle() -> TurnFlowDirective:
	return TurnFlowDirective.new()


static func blocked() -> TurnFlowDirective:
	var d := TurnFlowDirective.new()
	d.kind = Kind.BLOCKED
	return d


static func request_player_begin() -> TurnFlowDirective:
	var d := TurnFlowDirective.new()
	d.kind = Kind.REQUEST_PLAYER_BEGIN
	return d


static func request_arcana(proc: int) -> TurnFlowDirective:
	var d := TurnFlowDirective.new()
	d.kind = Kind.REQUEST_ARCANA
	d.arcana_proc = int(proc)
	return d


static func request_actor(actor_id: int) -> TurnFlowDirective:
	var d := TurnFlowDirective.new()
	d.kind = Kind.REQUEST_ACTOR
	d.actor_id = int(actor_id)
	return d


static func group_turn_ended(group_index: int) -> TurnFlowDirective:
	var d := TurnFlowDirective.new()
	d.kind = Kind.GROUP_TURN_ENDED
	d.group_index = int(group_index)
	return d
