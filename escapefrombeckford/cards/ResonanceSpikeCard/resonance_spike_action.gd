extends CardAction

@export var resonance_spike_intensity: int = 2
@export var sound: Sound = preload("uid://bpcpnxremq4xv")

func activate_sim(ctx: CardContext) -> bool:
	if ctx == null or ctx.api == null:
		return false

	var target_id := int(ctx.source_id)
	if target_id <= 0 or !ctx.api.is_alive(target_id):
		return false

	var s := StatusContext.new()
	s.source_id = int(ctx.source_id)
	s.target_id = target_id
	s.status_id = ResonanceSpikeStatus.ID
	s.intensity = int(resonance_spike_intensity)

	ctx.api.apply_status(s)

	if sound != null:
		ctx.api.play_sfx(sound)

	if !ctx.affected_ids.has(target_id):
		ctx.affected_ids.append(target_id)

	return true

func description_arity() -> int:
	return 1

func get_description_values(_ctx: CardActionContext) -> Array:
	return [resonance_spike_intensity]
