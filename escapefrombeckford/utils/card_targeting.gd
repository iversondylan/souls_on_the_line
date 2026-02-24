# card_targeting.gd
class_name CardTargeting extends RefCounted

static func resolve(api: BattleAPI, card: CardData, req: CardPlayRequest) -> CardResolvedTargetSim:
	var out := CardResolvedTargetSim.new()

	match card.target_type:
		CardData.TargetType.SELF:
			out.fighter_ids = PackedInt32Array([req.source_id])

		CardData.TargetType.SINGLE_ENEMY:
			if req.target_ids.size() > 0:
				out.fighter_ids = PackedInt32Array([req.target_ids[0]])

		CardData.TargetType.ALL_ENEMIES:
			if api.has_method("get_enemies_of"):
				out.fighter_ids = PackedInt32Array(api.call("get_enemies_of", req.source_id))
				
		CardData.TargetType.ALLY:
			if req.target_ids.size() > 0:
				out.fighter_ids = PackedInt32Array([req.target_ids[0]])
		
		CardData.TargetType.ALLY_OR_SELF:
			if req.target_ids.size() > 0:
				out.fighter_ids = PackedInt32Array([req.target_ids[0]])
				
		CardData.TargetType.EVERYONE:
			# you might add api.get_all_combatants() in sim
			if api.has_method("get_combatants_in_group"):
				var a :PackedInt32Array= api.call("get_combatants_in_group", 0, false)
				var b :PackedInt32Array= api.call("get_combatants_in_group", 1, false)
				out.fighter_ids = PackedInt32Array(a + b)

		CardData.TargetType.BATTLEFIELD:
			#out.area_index = req.area_index
			out.insert_index = req.insert_index # or req.params["insert_index"] if you want
	
	return out
