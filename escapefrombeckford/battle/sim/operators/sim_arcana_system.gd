# sim_arcana_system.gd

class_name SimArcanaSystem extends RefCounted

const SimArcanumContextScript = preload("res://battle/sim/containers/sim_arcanum_context.gd")


static func get_contexts(api: SimBattleAPI) -> Array:
	var out: Array = []
	if api == null or api.state == null or api.state.arcana == null or api.state.arcana_catalog == null:
		return out

	var owner_id := int(api.get_player_id())
	if owner_id <= 0:
		return out

	for entry: ArcanaState.ArcanumEntry in api.state.arcana.list:
		if entry == null or entry.id == &"":
			continue

		var proto: Arcanum = api.state.arcana_catalog.get_proto(entry.id)
		if proto == null:
			continue

		var ctx := SimArcanumContextScript.new(
			api,
			owner_id,
			SimBattleAPI.FRIENDLY,
			entry,
			proto
		)
		if ctx != null and ctx.is_valid():
			out.append(ctx)

	return out


static func on_battle_start(api: SimBattleAPI) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		if ctx.proto.procs_on_battle_start():
			ctx.proto.on_battle_start(ctx)


static func on_player_turn_begin(api: SimBattleAPI, _player_id: int) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		if ctx.proto.procs_on_player_turn_begin():
			ctx.proto.on_player_turn_begin(ctx)


static func on_player_turn_end(api: SimBattleAPI, _player_id: int) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		if ctx.proto.procs_on_player_turn_end():
			ctx.proto.on_player_turn_end(ctx)


static func on_battle_end(api: SimBattleAPI) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		if ctx.proto.procs_on_battle_end():
			ctx.proto.on_battle_end(ctx)


static func on_actor_turn_begin(api: SimBattleAPI, actor_id: int) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		ctx.proto.on_actor_turn_begin(ctx, actor_id)


static func on_actor_turn_end(api: SimBattleAPI, actor_id: int) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		ctx.proto.on_actor_turn_end(ctx, actor_id)


static func on_damage_will_be_taken(api: SimBattleAPI, damage_ctx: DamageContext) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		ctx.proto.on_damage_will_be_taken(ctx, damage_ctx)


static func on_damage_taken(api: SimBattleAPI, damage_ctx: DamageContext) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		ctx.proto.on_damage_taken(ctx, damage_ctx)


static func on_removal(api: SimBattleAPI, removal_ctx) -> void:
	for ctx in get_contexts(api):
		if ctx == null or !ctx.is_valid() or ctx.proto == null:
			continue
		ctx.proto.on_removal(ctx, removal_ctx)


static func get_modifier_tokens_for_target(
	api: SimBattleAPI,
	target_id: int,
	mod_type: Modifier.Type
) -> Array[ModifierToken]:
	var out: Array[ModifierToken] = []
	if api == null or api.state == null or target_id <= 0:
		return out

	for ctx in get_contexts(api):
		var proto: Arcanum = ctx.proto
		if proto == null:
			continue
		if !proto.contributes_modifier():
			continue
		if mod_type not in proto.get_contributed_modifier_types():
			continue

		var tokens := proto.get_modifier_tokens(ctx, target_id)
		for token in tokens:
			if SimBattleAPI._modifier_token_applies_to_target(token, target_id):
				out.append(token)

	return out
