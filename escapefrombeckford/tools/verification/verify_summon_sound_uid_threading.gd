extends SceneTree

const BattleEvent := preload("res://battle/sim/containers/battle_event.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CardContext := preload("res://cards/_core/card_context.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const Keys := preload("res://core/keys_values/keys.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const SummonActionResource := preload("res://cards/souls/SmolderingMascotCard/summon_smoldering_mascot.tres")
const SummonPopPresentationOrder := preload("res://battle/view/containers/summon_pop_presentation_order.gd")
const TurnTimelineCompiler := preload("res://battle/view/operators/turn_timeline_compiler.gd")

const SUMMON_SOUND_PATH := "res://audio/summon_zap.tres"


func _init() -> void:
	_verify_summon_event_threads_sound_uid()
	_verify_null_summon_sound_omits_payload()
	print("verify_summon_sound_uid_threading: ok")
	quit()


func _verify_summon_event_threads_sound_uid() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var action := SummonActionResource as SummonAction
	var expected_sound_uid := _resource_ref_string(SUMMON_SOUND_PATH)

	assert(action != null, "Summon action fixture should load.")
	assert(!expected_sound_uid.is_empty(), "Summon sound fixture should resolve to a stable resource reference.")

	var ctx := _activate_summon_action(sim, action)
	var summoned_event := _find_first_summoned_event(sim)
	assert(ctx.summoned_ids.size() == 1, "Summon action should produce one summoned id.")
	assert(summoned_event != null, "Summon action should emit a SUMMONED event.")
	assert(
		String(summoned_event.data.get(Keys.SUMMON_SOUND, "")) == expected_sound_uid,
		"SUMMONED event should carry the authored summon sound UID."
	)

	var compiler := TurnTimelineCompiler.new()
	var beat := compiler._make_summon_pop_beat(1.0, int(ctx.source_id), [summoned_event])
	assert(beat.orders.size() == 1, "Summon pop beat should contain one presentation order.")

	var order := beat.orders[0] as SummonPopPresentationOrder
	assert(order != null, "Summon pop beat should produce a summon pop presentation order.")
	assert(
		String(order.summon_sound_uid) == expected_sound_uid,
		"Summon pop presentation order should retain the summon sound UID."
	)


func _verify_null_summon_sound_omits_payload() -> void:
	var setup := _make_sim()
	var sim := setup.get("sim") as Sim
	var action := (SummonActionResource as SummonAction).duplicate(true) as SummonAction
	assert(action != null, "Duplicated summon action fixture should load.")
	action.sound = null

	var ctx := _activate_summon_action(sim, action)
	var summoned_event := _find_first_summoned_event(sim)
	assert(ctx.summoned_ids.size() == 1, "Null-sound summon should still resolve normally.")
	assert(summoned_event != null, "Null-sound summon should still emit a SUMMONED event.")
	assert(
		!summoned_event.data.has(Keys.SUMMON_SOUND),
		"Null summon sounds should not add a summon sound payload."
	)

	var compiler := TurnTimelineCompiler.new()
	var beat := compiler._make_summon_pop_beat(1.0, int(ctx.source_id), [summoned_event])
	assert(beat.orders.size() == 1, "Null-sound summon should still compile into a summon pop order.")

	var order := beat.orders[0] as SummonPopPresentationOrder
	assert(order != null, "Null-sound summon should still produce a summon pop presentation order.")
	assert(String(order.summon_sound_uid).is_empty(), "Null-sound summon pop order should stay silent.")


func _make_sim() -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(919, 202)
	sim.runtime.sim = sim
	sim.api.writer.allow_unscoped_events = true

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	_make_unit(sim.state, "Enemy", BattleState.ENEMY, CombatantView.Type.ENEMY, 30, 0)

	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, int(player.id))

	return {
		"sim": sim,
		"player_id": int(player.id),
	}


func _make_unit(
	state: BattleState,
	name: String,
	group_index: int,
	combatant_type: int,
	max_health: int,
	ap: int
) -> CombatantState:
	var unit := CombatantState.new()
	unit.id = state.alloc_id()
	unit.name = name
	unit.type = combatant_type
	unit.mortality = CombatantState.Mortality.MORTAL
	unit.max_health = max_health
	unit.health = max_health
	unit.ap = ap
	unit.alive = true
	state.add_unit(unit, group_index)
	return unit


func _activate_summon_action(sim: Sim, action: SummonAction) -> CardContext:
	var ctx := CardContext.new()
	ctx.api = sim.api
	ctx.runtime = sim.runtime
	ctx.source_id = int(sim.api.get_player_id())
	ctx.current_action_index = 0
	assert(action != null and action.activate_sim(ctx), "Summon action activation should succeed.")
	return ctx


func _find_first_summoned_event(sim: Sim) -> BattleEvent:
	if sim == null or sim.state == null or sim.state.events == null:
		return null
	var events := sim.state.events.read_range(0, sim.state.events.size())
	for event in events:
		if event != null and int(event.type) == int(BattleEvent.Type.SUMMONED):
			return event
	return null


func _resource_ref_string(path: String) -> String:
	if path.is_empty():
		return ""
	if path.begins_with("uid://"):
		return path
	var uid := ResourceLoader.get_resource_uid(path)
	if uid > 0:
		return ResourceUID.id_to_text(uid)
	return path
