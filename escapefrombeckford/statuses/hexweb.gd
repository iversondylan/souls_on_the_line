class_name HexwebStatus extends Status

const ID := &"hexweb"
const BOLSTERED := preload("res://statuses/bolstered.tres")

func get_id() -> StringName:
	return ID

func on_damage_taken(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or damage_ctx == null:
		return
	if int(damage_ctx.target_id) != int(ctx.owner_id):
		return
	if !_is_eligible_strike_damage(damage_ctx):
		return

	ctx.remove_self("hexweb_guard_triggered")
	if ctx.owner == null or !ctx.owner.is_alive() or BOLSTERED == null:
		return

	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = int(ctx.owner_id)
	status_ctx.status_id = BOLSTERED.get_id()
	status_ctx.stacks = 50
	status_ctx.reason = "hexweb"
	ctx.api.apply_status(status_ctx)

func get_tooltip(_stacks: int = 0) -> String:
	return "Hexweb: the first time each round this takes strike damage, gain 50% reduced damage for the rest of that round."

func _is_eligible_strike_damage(damage_ctx: DamageContext) -> bool:
	if damage_ctx == null:
		return false
	if int(damage_ctx.health_damage) <= 0:
		return false
	if !damage_ctx.tags.has(&"strike_damage"):
		return false
	if damage_ctx.tags.has(&"self_recoil"):
		return false
	return true
