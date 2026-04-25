extends SceneTree

const BattleEvent := preload("res://battle/sim/containers/battle_event.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CardContext := preload("res://cards/_core/card_context.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const DamageContext := preload("res://battle/contexts/damage_context.gd")
const Keys := preload("res://core/keys_values/keys.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const SimStatusSystem := preload("res://battle/sim/operators/sim_status_system.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")

const PULSE_WAVE := preload("res://cards/convocations/PulseWave/pulse_wave.tres")
const RENDING_REPAIR := preload("res://cards/convocations/RendingRepair/rending_repair.tres")
const DIAMOND_HEART := preload("res://cards/convocations/DiamondHeart/diamond_heart.tres")
const MOMENTUM := preload("res://cards/convocations/Momentum/momentum.tres")
const STAND_FIRM := preload("res://cards/convocations/StandFirm/stand_firm.tres")
const BARKBOUND_BOND := preload("res://cards/convocations/BarkboundBond/barkbound_bond.tres")

const COLE_DRAFTABLE_CARDS := preload("res://character_profiles/Cole/cole_draftable_cards.tres")
const BARKBOUND_BOND_STATUS_ID := &"barkbound_bond"
const SHIELD_TRANSMISSION_ID := &"shield_transmission"
const SHIELD_TRANSMISSION_GUARD_ID := &"shield_transmission_guard"
const ABSORB_ID := &"absorb"
const MIGHT_ID := &"might"

func _init() -> void:
	_verify_pulse_wave()
	_verify_rending_repair()
	_verify_diamond_heart()
	_verify_momentum()
	_verify_stand_firm()
	_verify_barkbound_bond()
	_verify_draft_pool()
	_verify_status_catalog()
	print("verify_cole_convocation_pack: ok")
	quit()

func _verify_pulse_wave() -> void:
	var setup := _make_sim(4, 8, 4, 6, 30)
	var sim := setup.get("sim") as Sim
	var ally_state := setup.get("ally_1") as CombatantState
	var ally := int(ally_state.id)
	var draw_before := _draw_amount(sim)
	_play_card(sim, PULSE_WAVE, ally)
	assert(int(ally_state.max_health) == 10, "Pulse Wave should grant Fortitude 2 at half HP or below.")
	assert(int(ally_state.health) == 10, "Pulse Wave should fully heal and fill added health.")
	assert(_draw_amount(sim) - draw_before == 1, "Pulse Wave should draw when it buffs.")

	setup = _make_sim(5, 8, 4, 6, 30)
	sim = setup.get("sim") as Sim
	ally_state = setup.get("ally_1") as CombatantState
	ally = int(ally_state.id)
	draw_before = _draw_amount(sim)
	_play_card(sim, PULSE_WAVE, ally)
	assert(int(ally_state.max_health) == 8, "Pulse Wave should not grant max health above half HP.")
	assert(int(ally_state.health) == 8, "Pulse Wave should still heal the ally.")
	assert(_draw_amount(sim) - draw_before == 0, "Pulse Wave should not draw above half HP.")

func _verify_rending_repair() -> void:
	var setup := _make_sim(5, 8, 4, 6, 30)
	var sim := setup.get("sim") as Sim
	var ally_state := setup.get("ally_1") as CombatantState
	var enemy_state := setup.get("enemy_1") as CombatantState
	ally_state.ap = 5
	var enemy_before := int(enemy_state.health)
	_play_card(sim, RENDING_REPAIR, int(ally_state.id))
	assert(int(ally_state.health) == 8, "Rending Repair should heal the ally.")
	assert(enemy_before - int(enemy_state.health) == 8, "Rending Repair should add healed amount to the attack.")

	setup = _make_sim(8, 8, 4, 6, 30)
	sim = setup.get("sim") as Sim
	ally_state = setup.get("ally_1") as CombatantState
	enemy_state = setup.get("enemy_1") as CombatantState
	ally_state.ap = 5
	enemy_before = int(enemy_state.health)
	_play_card(sim, RENDING_REPAIR, int(ally_state.id))
	assert(enemy_before - int(enemy_state.health) == 5, "Rending Repair should still attack when the heal amount is 0.")

func _verify_diamond_heart() -> void:
	var setup := _make_sim(7, 8, 6, 6, 30)
	var sim := setup.get("sim") as Sim
	var ally_1_state := setup.get("ally_1") as CombatantState
	var ally_2_state := setup.get("ally_2") as CombatantState
	var ally_1 := int(ally_1_state.id)
	var ally_2 := int(ally_2_state.id)
	var draw_before := _draw_amount(sim)
	_play_card(sim, DIAMOND_HEART, ally_1)
	assert(_status_stacks(sim, ally_1, SHIELD_TRANSMISSION_ID) == 1, "Diamond Heart should apply Shield Transmission.")
	assert(_status_stacks(sim, ally_1, SHIELD_TRANSMISSION_GUARD_ID) == -1, "Diamond Heart should not trigger its own damage reduction.")
	assert(_draw_amount(sim) - draw_before == 1, "Diamond Heart should draw 1.")

	_play_card(sim, MOMENTUM, ally_2)
	assert(_status_stacks(sim, ally_1, SHIELD_TRANSMISSION_GUARD_ID) == 25, "Shield Transmission should trigger on the next Convocation.")

	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	assert(_status_stacks(sim, ally_1, SHIELD_TRANSMISSION_GUARD_ID) == -1, "Shield Transmission guard should clear at player turn start.")

func _verify_momentum() -> void:
	var setup := _make_sim(7, 9, 4, 6, 30)
	var sim := setup.get("sim") as Sim
	var ally_state := setup.get("ally_1") as CombatantState
	var enemy_state := setup.get("enemy_1") as CombatantState
	var enemy_before := int(enemy_state.health)
	_play_card(sim, MOMENTUM, int(ally_state.id))
	assert(enemy_before - int(enemy_state.health) == 9, "Momentum should deal damage equal to the ally's max health.")

func _verify_stand_firm() -> void:
	var setup := _make_sim(5, 8, 4, 6, 30)
	var sim := setup.get("sim") as Sim
	var ally_state := setup.get("ally_1") as CombatantState
	var ally := int(ally_state.id)
	var draw_before := _draw_amount(sim)
	_play_card(sim, STAND_FIRM, ally)
	assert(int(ally_state.max_health) == 10 and int(ally_state.health) == 7, "Stand Firm should grant Fortitude 2.")
	assert(_status_stacks(sim, ally, ABSORB_ID) == 1, "Stand Firm should grant Absorb when the target is still damaged.")
	assert(_draw_amount(sim) - draw_before == 0, "Stand Firm should not draw when it grants Absorb.")

	setup = _make_sim(8, 8, 4, 6, 30)
	sim = setup.get("sim") as Sim
	ally_state = setup.get("ally_1") as CombatantState
	ally = int(ally_state.id)
	draw_before = _draw_amount(sim)
	_play_card(sim, STAND_FIRM, ally)
	assert(int(ally_state.max_health) == 10 and int(ally_state.health) == 10, "Stand Firm should fill the added max health.")
	assert(_status_stacks(sim, ally, ABSORB_ID) == -1, "Stand Firm should not grant Absorb to an undamaged target.")
	assert(_draw_amount(sim) - draw_before == 1, "Stand Firm should draw when the target is undamaged.")

func _verify_barkbound_bond() -> void:
	var setup := _make_sim(8, 8, 4, 6, 30)
	var sim := setup.get("sim") as Sim
	var ally_state := setup.get("ally_1") as CombatantState
	var enemy_state := setup.get("enemy_1") as CombatantState
	var ally := int(ally_state.id)
	var draw_before := _draw_amount(sim)
	_play_card(sim, BARKBOUND_BOND, ally)
	assert(_draw_amount(sim) - draw_before == 1, "Barkbound Bond should draw 1.")
	assert(_status_stacks(sim, ally, BARKBOUND_BOND_STATUS_ID) == 2, "Barkbound Bond should start with 2 triggers.")

	_apply_direct_damage(sim, int(enemy_state.id), ally, 1)
	assert(_status_stacks(sim, ally, MIGHT_ID) == 1, "Barkbound Bond should grant +1 Might on first trigger.")
	assert(int(ally_state.max_health) == 10, "Barkbound Bond should grant Fortitude 2 on first trigger.")

	_apply_direct_damage(sim, int(enemy_state.id), ally, 1)
	assert(_status_stacks(sim, ally, MIGHT_ID) == 2, "Barkbound Bond should grant +1 Might on second trigger.")
	assert(int(ally_state.max_health) == 12, "Barkbound Bond should grant Fortitude 2 on second trigger.")
	assert(_status_stacks(sim, ally, BARKBOUND_BOND_STATUS_ID) == -1, "Barkbound Bond should consume itself after 2 triggers.")

	var health_before := int(ally_state.health)
	_apply_direct_damage(sim, int(enemy_state.id), ally, 1)
	assert(_status_stacks(sim, ally, MIGHT_ID) == 2, "Barkbound Bond should stop triggering after it is spent.")
	assert(int(ally_state.max_health) == 12, "Barkbound Bond should not add more max health after 2 triggers.")
	assert(int(ally_state.health) == health_before - 1, "Post-bond damage should no longer be offset by Fortitude.")

func _verify_draft_pool() -> void:
	var expected_ids := {
		&"pulse_wave": true,
		&"rending_repair": true,
		&"diamond_heart": true,
		&"momentum": true,
		&"stand_firm": true,
		&"barkbound_bond": true,
	}
	for card in COLE_DRAFTABLE_CARDS.cards:
		if card == null:
			continue
		expected_ids.erase(card.id)
	assert(expected_ids.is_empty(), "Cole draft pool is missing one or more new Convocations: %s" % str(expected_ids.keys()))

func _verify_status_catalog() -> void:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()
	assert(status_catalog.get_proto(SHIELD_TRANSMISSION_ID) != null, "Status catalog should include Shield Transmission.")
	assert(status_catalog.get_proto(SHIELD_TRANSMISSION_GUARD_ID) != null, "Status catalog should include Shield Transmission Guard.")
	assert(status_catalog.get_proto(BARKBOUND_BOND_STATUS_ID) != null, "Status catalog should include Barkbound Bond.")

func _make_sim(ally_1_health: int, ally_1_max: int, ally_2_health: int, ally_2_max: int, enemy_health: int) -> Dictionary:
	var status_catalog := StatusCatalogResource.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(101, 202)
	sim.runtime.sim = sim

	sim.state.resource.max_mana = 99
	sim.state.resource.mana = 99
	sim.api.writer.allow_unscoped_events = true

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	var ally_1 := _make_unit(sim.state, "Ally 1", BattleState.FRIENDLY, CombatantView.Type.ALLY, ally_1_max, 4)
	ally_1.health = ally_1_health
	var ally_2 := _make_unit(sim.state, "Ally 2", BattleState.FRIENDLY, CombatantView.Type.ALLY, ally_2_max, 3)
	ally_2.health = ally_2_health
	var enemy_1 := _make_unit(sim.state, "Enemy", BattleState.ENEMY, CombatantView.Type.ENEMY, enemy_health, 0)

	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, int(player.id))

	return {
		"sim": sim,
		"player": player,
		"ally_1": ally_1,
		"ally_2": ally_2,
		"enemy_1": enemy_1,
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

func _play_card(sim: Sim, proto: CardData, target_id: int) -> CardContext:
	var card := proto.make_runtime_instance()
	var ctx := CardContext.new()
	ctx.api = sim.api
	ctx.runtime = sim.runtime
	ctx.source_id = int(sim.api.get_player_id())
	ctx.card_data = card
	ctx.target_ids = PackedInt32Array([target_id])
	if sim.api.state != null and sim.api.state.turn != null:
		sim.api.state.turn.card_ids_played_this_turn.append(card.id)
		sim.api.state.turn.card_types_played_this_turn.append(int(card.card_type))
	SimStatusSystem.on_card_played(sim.api, int(ctx.source_id), card)
	for action in card.actions:
		assert(action != null and action.activate_sim(ctx), "Card action failed for %s" % String(card.name))
	return ctx

func _apply_direct_damage(sim: Sim, source_id: int, target_id: int, amount: int) -> void:
	var damage_ctx := DamageContext.new()
	damage_ctx.source_id = source_id
	damage_ctx.target_id = target_id
	damage_ctx.base_amount = amount
	damage_ctx.reason = "verify_cole_convocation_pack"
	sim.api.resolve_damage_immediate(damage_ctx)

func _draw_amount(sim: Sim) -> int:
	var total := 0
	for i in range(sim.state.events.size()):
		var event := sim.state.events.get_event(i)
		if event == null or int(event.type) != int(BattleEvent.Type.DRAW_CARDS):
			continue
		total += int(event.data.get(Keys.AMOUNT, 0))
	return total

func _status_stacks(sim: Sim, target_id: int, status_id: StringName) -> int:
	return int(sim.api.get_status_stacks(target_id, status_id))
