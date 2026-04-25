extends SceneTree

const ArcanaCatalog := preload("res://arcana/_core/arcana_catalog.gd")
const ArcanaCatalogResource := preload("res://arcana/_core/arcanum_catalog.tres")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CardData := preload("res://cards/_core/card_data.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const ManaContext := preload("res://battle/contexts/mana_context.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const SimArcanaSystem := preload("res://battle/sim/operators/sim_arcana_system.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")

const SIGIL_OF_MANA_ID := &"sigil_of_mana"


func _init() -> void:
	_verify_sigil_of_mana_can_exceed_reset_amount()
	_verify_set_max_mana_without_refill_keeps_current_mana()
	_verify_set_max_mana_with_refill_resets_current_mana()
	_verify_spending_above_reset_amount_still_works()
	print("verify_mana_reset_semantics: ok")
	quit()


func _verify_sigil_of_mana_can_exceed_reset_amount() -> void:
	var sim := _make_sim(true)
	assert(int(sim.state.resource.mana) == 3, "Base sim should start with 3 mana.")
	assert(int(sim.state.resource.max_mana) == 3, "Base sim should start with a reset amount of 3.")

	SimArcanaSystem.on_battle_start(sim.api)

	assert(int(sim.state.resource.mana) == 4, "Sigil of Mana should increase current mana above the reset amount.")
	assert(int(sim.state.resource.max_mana) == 3, "Sigil of Mana should not change the reset amount.")

	_apply_player_turn_refresh(sim)

	assert(int(sim.state.resource.mana) == 3, "Friendly turn refresh should reset current mana back to max_mana.")
	assert(int(sim.state.resource.max_mana) == 3, "Friendly turn refresh should preserve the reset amount.")


func _verify_set_max_mana_without_refill_keeps_current_mana() -> void:
	var sim := _make_sim(false)
	sim.state.resource.max_mana = 3
	sim.state.resource.mana = 5

	var mana_ctx := ManaContext.new()
	mana_ctx.source_id = int(sim.api.get_player_id())
	mana_ctx.mode = ManaContext.Mode.SET_MAX_MANA
	mana_ctx.reason = "verify_set_max_no_refill"
	mana_ctx.new_max_mana = 2
	mana_ctx.refill = false
	sim.api.set_max_mana(mana_ctx)

	assert(int(sim.state.resource.max_mana) == 2, "set_max_mana should update the reset amount.")
	assert(int(sim.state.resource.mana) == 5, "set_max_mana without refill should not reduce current mana.")


func _verify_set_max_mana_with_refill_resets_current_mana() -> void:
	var sim := _make_sim(false)
	sim.state.resource.max_mana = 3
	sim.state.resource.mana = 5

	var mana_ctx := ManaContext.new()
	mana_ctx.source_id = int(sim.api.get_player_id())
	mana_ctx.mode = ManaContext.Mode.SET_MAX_MANA
	mana_ctx.reason = "verify_set_max_with_refill"
	mana_ctx.new_max_mana = 2
	mana_ctx.refill = true
	sim.api.set_max_mana(mana_ctx)

	assert(int(sim.state.resource.max_mana) == 2, "set_max_mana should still update the reset amount when refill is true.")
	assert(int(sim.state.resource.mana) == 2, "set_max_mana with refill should set current mana to the new reset amount.")


func _verify_spending_above_reset_amount_still_works() -> void:
	var sim := _make_sim(false)
	sim.state.resource.max_mana = 3
	sim.state.resource.mana = 5

	var card := CardData.new()
	card.id = &"verify_card"
	card.name = "Verify Card"
	card.cost = 4

	var mana_ctx := ManaContext.new()
	mana_ctx.source_id = int(sim.api.get_player_id())
	var paid := sim.api.spend_mana_for_card(mana_ctx, card)

	assert(paid, "Cards should be payable from current mana even above the reset amount.")
	assert(int(sim.state.resource.mana) == 1, "Card spending should subtract from current mana normally.")
	assert(int(sim.state.resource.max_mana) == 3, "Card spending should not change the reset amount.")


func _make_sim(include_sigil_of_mana: bool) -> Sim:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var arcana_catalog := ArcanaCatalogResource.duplicate(true) as ArcanaCatalog
	arcana_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.arcana_catalog = arcana_catalog
	sim.init_from_seeds(515, 919)
	sim.runtime.sim = sim
	sim.api.writer.allow_unscoped_events = true

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, int(player.id))

	if include_sigil_of_mana:
		sim.state.arcana.add_arcanum(SIGIL_OF_MANA_ID)

	return sim


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
	unit.team = group_index
	unit.type = combatant_type
	unit.name = name
	unit.mortality = CombatantState.Mortality.MORTAL
	unit.max_health = max_health
	unit.health = max_health
	unit.ap = ap
	unit.alive = true
	state.add_unit(unit, group_index)
	return unit


func _apply_player_turn_refresh(sim: Sim) -> void:
	var mana_ctx := ManaContext.new()
	mana_ctx.source_id = int(sim.api.get_player_id())
	mana_ctx.mode = ManaContext.Mode.REFRESH_FOR_GROUP_TURN
	mana_ctx.group_index = int(BattleState.FRIENDLY)
	mana_ctx.reason = "group_turn_begin_refresh"
	mana_ctx.new_mana = int(sim.state.resource.max_mana)
	sim.api.set_mana(mana_ctx)
