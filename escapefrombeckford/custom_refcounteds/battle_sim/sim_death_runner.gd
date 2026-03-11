# sim_death_runner.gd

class_name SimDeathRunner extends RefCounted

static func run(api: SimBattleAPI, dead_id: int, killer_id: int = 0, reason: String = "") -> void:
	if api == null or api.state == null:
		return
	if dead_id <= 0:
		return
	
	var u: CombatantState = api.state.get_unit(dead_id)
	if u == null:
		return
	if !u.alive:
		return
	
	var g := int(u.team)
	
	# Beat 1: target goes dark
	if api.writer != null:
		api.writer.emit_death_windup(killer_id, dead_id, reason, g)
	
	# Finalize removal before followthrough (so layout can use new order)
	u.alive = false
	if g != -1:
		api.state.groups[g].remove(dead_id)

	var after_order_ids := PackedInt32Array(api.state.groups[g].order) if g != -1 else PackedInt32Array()
	if api.on_unit_removed.is_valid():
		api.on_unit_removed.call(int(dead_id), int(g), "death:" + reason)
	# Beat 2: group re-layout
	if api.writer != null:
		api.writer.emit_death_followthrough(killer_id, dead_id, reason, g, after_order_ids)

	# Non-beat: actual "DIED" semantic marker
	if api.writer != null:
		api.writer.emit_died(killer_id, dead_id, after_order_ids, reason, g)
