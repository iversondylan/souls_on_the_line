class_name PocketSilkstitchersStatus extends Status

const ID := &"pocket_silkstitchers"
const MIGHT := preload("res://statuses/might.tres")
const FULL_FORTITUDE := preload("res://statuses/full_fortitude.tres")

func get_id() -> StringName:
	return ID

func listens_for_player_turn_begin() -> bool:
	return true

func listens_for_any_damage_applied() -> bool:
	return true

func on_apply(ctx: SimStatusContext, _apply_ctx: StatusContext) -> void:
	if ctx == null or !ctx.is_valid():
		return
	ctx.set_token_data_value(Keys.ARMED, true, "pocket_silkstitchers_apply")

func on_player_turn_begin(ctx: SimStatusContext, player_id: int) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null:
		return
	if int(player_id) != int(ctx.api.get_player_id()):
		return
	ctx.set_token_data_value(Keys.ARMED, true, "pocket_silkstitchers_rearm")

func on_any_damage_applied(ctx: SimStatusContext, damage_ctx: DamageContext) -> void:
	if ctx == null or !ctx.is_valid() or ctx.api == null or ctx.owner == null or damage_ctx == null:
		return
	if !ctx.get_token_data_bool(Keys.ARMED, true):
		return
	if int(damage_ctx.health_damage) <= 0:
		return
	if bool(damage_ctx.was_lethal):
		return
	if !damage_ctx.tags.has(&"strike_damage"):
		return
	if damage_ctx.tags.has(&"self_recoil"):
		return

	var target := ctx.api.state.get_unit(int(damage_ctx.target_id)) if ctx.api.state != null else null
	if target == null or !target.is_alive():
		return
	if int(target.team) != int(ctx.owner.team):
		return
	if int(target.id) == int(ctx.api.get_player_id()):
		return

	_apply_status_to_target(ctx, int(target.id), MIGHT, 1, "pocket_silkstitchers_might")
	_apply_status_to_target(ctx, int(target.id), FULL_FORTITUDE, 2, "pocket_silkstitchers_fortitude")
	ctx.set_token_data_value(Keys.ARMED, false, "pocket_silkstitchers_spent")

func get_tooltip(_stacks: int = 0) -> String:
	return "Once each round, the first time an ally survives attack damage, it gains +1 Might and +2 Full Fortitude."

func _apply_status_to_target(ctx: SimStatusContext, target_id: int, status: Status, stacks: int, reason: String) -> void:
	if ctx == null or status == null or target_id <= 0:
		return
	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(ctx.owner_id)
	status_ctx.target_id = target_id
	status_ctx.status_id = status.get_id()
	status_ctx.stacks = stacks
	status_ctx.reason = reason
	ctx.api.apply_status(status_ctx)
