extends CardAction

class_name StatusApplyAction

@export var status: Status
@export var intensity: int = 0
@export var duration: int = 0
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
	sctx.intensity = int(intensity)
	sctx.duration = int(duration)
	sctx.pending = bool(pending)

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


func description_arity() -> int:
	return get_description_values(CardActionContext.new()).size()


func get_description_values(_ctx: CardActionContext) -> Array:
	if status == null:
		return []

	if _has_property(status, "max_health_per_strike"):
		return [int(status.get("max_health_per_strike"))]

	var status_id := status.get_id()
	if status_id == AmplifyStatus.ID:
		return [floori(float(AmplifyStatus.MULT_VALUE) * 100.0), int(duration)]
	if status_id == PinpointStatus.ID:
		return [floori(float(PinpointStatus.MULT_VALUE) * 100.0), int(duration)]
	if status_id == MarkedStatus.ID:
		return [int(duration)]

	if int(duration) > 0 and int(intensity) > 0:
		return [int(intensity), int(duration)]
	if int(intensity) > 0:
		return [int(intensity)]
	if int(duration) > 0:
		return [int(duration)]

	return []


func _has_property(obj: Object, property_name: String) -> bool:
	if obj == null:
		return false
	for prop in obj.get_property_list():
		if String(prop.get("name", "")) == property_name:
			return true
	return false
