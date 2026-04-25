extends CardAction

class_name StatusApplyAction

@export var status: Status
@export var stacks: int = 0
@export var pending: bool = false
@export var sound: Sound = null
@export var play_sound_on_success: bool = false

func _apply_status_to_target(ctx: CardContext, target_id: int) -> bool:
	if ctx == null or ctx.api == null:
		return false
	if status == null:
		push_warning("status_apply_action.gd _apply_status_to_target(): missing status")
		return false
	if target_id <= 0 or !ctx.api.is_alive(int(target_id)):
		return false

	var sctx := StatusContext.new()
	sctx.source_id = int(ctx.source_id)
	sctx.target_id = int(target_id)
	sctx.status_id = status.get_id()
	sctx.stacks = int(stacks)
	sctx.pending = bool(pending)
	if ctx.card_data != null:
		ctx.card_data.ensure_uid()
		sctx.origin_card_uid = String(ctx.card_data.uid)

	ctx.api.apply_status(sctx)
	if !ctx.affected_ids.has(int(target_id)):
		ctx.affected_ids.append(int(target_id))
	return true


func _play_success_sound(ctx: CardContext, applied_any: bool) -> void:
	if !applied_any:
		return
	if !bool(play_sound_on_success):
		return
	if sound == null or ctx == null or ctx.api == null:
		return
	ctx.api.play_sfx(sound)


func get_description_value(_ctx: CardActionContext) -> String:
	if status == null:
		return ""

	if status.numerical and int(stacks) > 0:
		return str(int(stacks))

	return String(status.status_name)
