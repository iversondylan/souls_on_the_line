extends CardAction

class_name ApplyStatusToAllEnemiesBySacrificedPositionAction

@export var status_if_in_front: Status
@export var intensity_if_in_front: int = 0
@export var duration_if_in_front: int = 0
@export var pending_if_in_front: bool = false

@export var status_if_behind: Status
@export var intensity_if_behind: int = 0
@export var duration_if_behind: int = 0
@export var pending_if_behind: bool = false

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var pos_delta := int(ctx.affected_target_player_pos_delta)
	if pos_delta == 0:
		return false

	var enemy_ids := ctx.api.get_enemies_of(int(ctx.source_id))
	if enemy_ids.is_empty():
		return false

	var status_to_apply: Status = status_if_in_front if pos_delta < 0 else status_if_behind
	if status_to_apply == null:
		return false

	var intensity := int(intensity_if_in_front) if pos_delta < 0 else int(intensity_if_behind)
	var duration := int(duration_if_in_front) if pos_delta < 0 else int(duration_if_behind)
	var pending := bool(pending_if_in_front) if pos_delta < 0 else bool(pending_if_behind)

	var applied_any := false
	for enemy_id in enemy_ids:
		var target_id := int(enemy_id)
		if target_id <= 0 or !ctx.api.is_alive(target_id):
			continue

		var sctx := StatusContext.new()
		sctx.source_id = int(ctx.source_id)
		sctx.target_id = target_id
		sctx.status_id = status_to_apply.get_id()
		sctx.intensity = intensity
		sctx.duration = duration
		sctx.pending = pending
		ctx.api.apply_status(sctx)
		applied_any = true

		if !ctx.affected_ids.has(target_id):
			ctx.affected_ids.append(target_id)

	return applied_any


func description_arity() -> int:
	return 0
