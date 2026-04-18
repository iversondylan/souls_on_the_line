# card_targeting.gd
class_name CardTargeting extends RefCounted

static func get_valid_targets(card_data: CardData, actor_id: int, api: SimBattleAPI) -> Array[int]:
	var out: Array[int] = []
	if card_data == null or api == null or actor_id <= 0:
		return out

	# Serialized card assets currently rely on enum ordinal mapping:
	# Allies == CardData.TargetType.ALLY == 3
	if int(CardData.TargetType.ALLY) != 3:
		push_error("CardData.TargetType.ALLY enum value changed; serialized target_type mappings must be updated.")
	if OS.is_debug_build():
		assert(int(CardData.TargetType.ALLY) == 3, "CardData.TargetType.ALLY enum value changed; serialized target_type mappings must be updated.")

	match int(card_data.target_type):
		CardData.TargetType.SELF:
			out.append(int(actor_id))

		CardData.TargetType.SINGLE_ENEMY, CardData.TargetType.ALL_ENEMIES:
			out.append_array(api.get_enemies_of(int(actor_id)))

		CardData.TargetType.ALLY:
			out.append_array(_filter_non_player_targets(api.get_allies_of(int(actor_id)), api.get_player_id()))

		CardData.TargetType.ALLY_OR_SELF:
			out.append_array(_filter_non_player_targets(api.get_allies_of(int(actor_id)), api.get_player_id()))
			if int(actor_id) > 0 and !out.has(int(actor_id)):
				out.append(int(actor_id))

		CardData.TargetType.EVERYONE:
			out.append_array(api.get_combatants_in_group(SimBattleAPI.FRIENDLY, false))
			out.append_array(api.get_combatants_in_group(SimBattleAPI.ENEMY, false))

	return out

static func is_valid_target(card_data: CardData, actor_id: int, target_id: int, api: SimBattleAPI) -> bool:
	if target_id <= 0:
		return false
	return get_valid_targets(card_data, actor_id, api).has(int(target_id))

static func resolve(api: SimBattleAPI, card: CardData, req: CardPlayRequest) -> CardResolvedTargetSim:
	var out := CardResolvedTargetSim.new()
	if api == null or card == null or req == null:
		return out

	var valid_ids := get_valid_targets(card, req.source_id, api)
	var requested_ids := req.target_ids

	match card.target_type:
		CardData.TargetType.SELF:
			out.fighter_ids = PackedInt32Array(valid_ids)

		CardData.TargetType.SINGLE_ENEMY:
			var target_id := _first_valid_requested_target(requested_ids, valid_ids)
			if target_id > 0:
				out.fighter_ids = PackedInt32Array([target_id])

		CardData.TargetType.ALL_ENEMIES:
			out.fighter_ids = PackedInt32Array(valid_ids)
			
		CardData.TargetType.ALLY:
			var target_id := _first_valid_requested_target(requested_ids, valid_ids)
			if target_id > 0:
				out.fighter_ids = PackedInt32Array([target_id])
		
		CardData.TargetType.ALLY_OR_SELF:
			var target_id := _first_valid_requested_target(requested_ids, valid_ids)
			if target_id > 0:
				out.fighter_ids = PackedInt32Array([target_id])
				
		CardData.TargetType.EVERYONE:
			out.fighter_ids = PackedInt32Array(valid_ids)

		CardData.TargetType.BATTLEFIELD:
			#out.area_index = req.area_index
			out.insert_index = req.insert_index # or req.params["insert_index"] if you want
	
	return out

static func _filter_non_player_targets(target_ids: Array[int], player_id: int) -> Array[int]:
	var out: Array[int] = []
	var pid := int(player_id)
	for id in target_ids:
		var cid := int(id)
		if cid <= 0:
			continue
		if cid == pid:
			continue
		out.append(cid)
	return out

static func _first_valid_requested_target(requested_ids: PackedInt32Array, valid_ids: Array[int]) -> int:
	for id in requested_ids:
		var cid := int(id)
		if valid_ids.has(cid):
			return cid
	return 0
