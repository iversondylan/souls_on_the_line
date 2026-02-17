# turn_engine_host_live.gd

class_name TurnEngineHostLive extends TurnEngineHost

var battle_scene: BattleScene
#var battle: Battle

func _init(_battle_scene: BattleScene) -> void:
	battle_scene = _battle_scene

func get_player_id() -> int:
	var p := battle_scene.player
	return int(p.combat_id)

func get_group_order_ids(group_index: int) -> PackedInt32Array:
	var g: BattleGroup = battle_scene.get_group_by_index(group_index)
	var fighters := g.get_combatants(false)
	var out := PackedInt32Array()
	print("turn_engine_hose_live.gd get_group_order_ids() group=", group_index, " node=", g.name, " fighters_n=", fighters.size())
	for f in fighters:
		print("\t", f.name, " cid=", int(f.combat_id), " alive=", f.is_alive(), " idx=", f.get_index())
		out.append(int(f.combat_id))
	print("\t=> out=", out)
	return out


#func get_group_order_ids(group_index: int) -> PackedInt32Array:
	#var g: BattleGroup = battle_scene.get_group_by_index(group_index)
	#var fighters := g.get_combatants(false)
	#var out := PackedInt32Array()
	#for f in fighters:
		#out.append(int(f.combat_id))
	#return out

func get_group_index_of(combat_id: int) -> int:
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	if !f:
		return -1
	return f.battle_scene.groups.find(f.battle_group)
	#return f.battle_group.group_index # or however you store it

func is_alive(combat_id: int) -> bool:
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	return f != null and is_instance_valid(f) and f.is_alive()

func is_player(combat_id: int) -> bool:
	var f := battle_scene.get_combatant_by_id(combat_id, true)
	return f != null and is_instance_valid(f) and (f is Player)
