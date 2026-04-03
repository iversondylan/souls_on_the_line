# unruly_pyric_wraps.gd

extends Arcanum

const ID := &"unruly_pyric_wraps"

@export var damage: int = 2

func get_id() -> StringName:
	return ID

func on_player_turn_begin(ctx) -> void:
	var api: SimBattleAPI = ctx.api if ctx != null else null
	if api == null:
		return

	var source_id := int(api.get_player_id())
	if source_id <= 0:
		return

	var enemy_ids: Array[int] = []
	enemy_ids = api.get_enemies_of(source_id)
	for tid in enemy_ids:
		_apply_damage(api, source_id, int(tid), damage)


func _apply_damage(api: SimBattleAPI, source_id: int, target_id: int, amount: int) -> void:
	if api == null or target_id <= 0:
		return
	var d := DamageContext.new()
	d.api = api
	d.source_id = source_id
	d.target_id = target_id
	d.base_amount = amount
	d.deal_modifier_type = int(Modifier.Type.NO_MODIFIER)
	d.take_modifier_type = int(Modifier.Type.NO_MODIFIER)
	d.origin_arcanum_id = get_id()
	d.reason = "arcanum_player_turn_begin"
	api.resolve_damage_immediate(d)

func get_beats() -> int:
	return Beats.IN_OUT
