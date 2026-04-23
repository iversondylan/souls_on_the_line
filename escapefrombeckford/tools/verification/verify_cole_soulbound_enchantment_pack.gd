extends SceneTree

const ActionLifecycleSystem := preload("res://battle/sim/operators/action_lifecycle_system.gd")
const BattleEvent := preload("res://battle/sim/containers/battle_event.gd")
const BattleEventLog := preload("res://battle/sim/logging/battle_event_log.gd")
const BattleState := preload("res://battle/sim/containers/battle_state.gd")
const CardContext := preload("res://cards/_core/card_context.gd")
const CardData := preload("res://cards/_core/card_data.gd")
const CombatantState := preload("res://battle/sim/containers/combatant_state.gd")
const CombatantView := preload("res://battle/view/scenes/combatant_view.gd")
const DamageContext := preload("res://battle/contexts/damage_context.gd")
const Keys := preload("res://core/keys_values/keys.gd")
const PresentationOrder := preload("res://battle/view/containers/presenation_order.gd")
const Scope := preload("res://core/keys_values/scope_values.gd")
const Sim := preload("res://battle/sim/operators/sim.gd")
const SimStatusSystem := preload("res://battle/sim/operators/sim_status_system.gd")
const Status := preload("res://statuses/_core/status.gd")
const StatusCatalog := preload("res://statuses/_core/status_catalog.gd")
const StatusCatalogResource := preload("res://statuses/_core/status_catalog.tres")
const StatusTokenContext := preload("res://battle/contexts/status_token_context.gd")
const TurnTimelineCompiler := preload("res://battle/view/operators/turn_timeline_compiler.gd")

const AYE_AYE_ASCETIC := preload("res://cards/souls/AxolotlAsceticCard/axolotl_ascetic_card.tres")
const ENTANGLED_VOTARY := preload("res://cards/souls/EntangledVotaryCard/entangled_votary_card.tres")
const PHOENIX_BROOCH := preload("res://cards/enchantments/PhoenixBrooch/phoenix_brooch.tres")
const POCKET_SILKSTITCHERS := preload("res://cards/enchantments/PocketSilkstitchers/pocket_silkstitchers.tres")
const DOMINION_ROSTER := preload("res://cards/enchantments/DominionRoster/dominion_roster.tres")
const JABBER_COLLECTOR := preload("res://cards/enchantments/JabberCollector/jabber_collector.tres")
const MOMENTUM := preload("res://cards/convocations/Momentum/momentum.tres")
const COLE_DRAFTABLE_CARDS := preload("res://character_profiles/Cole/cole_draftable_cards.tres")
const STATUS_CATALOG_RESOURCE := preload("res://statuses/_core/status_catalog.tres")
const BULWARK_PROTO := preload("res://statuses/bulwark.tres")

const AYE_AYE_THRESHOLD_ID := &"ascetic_threshold"
const ENTANGLED_GROWTH_ID := &"entangled_votary_growth"
const PHOENIX_BROOCH_ID := &"phoenix_brooch"
const POCKET_SILKSTITCHERS_ID := &"pocket_silkstitchers"
const DOMINION_ROSTER_ID := &"dominion_roster"
const JABBER_COLLECTOR_ID := &"jabber_collector"
const BULWARK_ID := &"bulwark"
const MIGHT_ID := &"might"
const ABSORB_ID := &"absorb"

func _init() -> void:
	_verify_aye_aye_ascetic()
	_verify_entangled_votary()
	_verify_phoenix_brooch()
	_verify_phoenix_brooch_timeline_sync()
	_verify_battle_event_log_debug_printer()
	_verify_pocket_silkstitchers()
	_verify_dominion_roster()
	_verify_jabber_collector()
	_verify_bulwark()
	_verify_draft_pool()
	_verify_status_catalog()
	print("verify_cole_soulbound_enchantment_pack: ok")
	quit()

func _verify_aye_aye_ascetic() -> void:
	var setup := _make_sim(30)
	var sim := setup.get("sim") as Sim
	var ctx := _play_card(sim, AYE_AYE_ASCETIC)
	assert(!ctx.summoned_ids.is_empty(), "Aye-Aye Ascetic should summon a bound ally.")
	var summoned_id := int(ctx.summoned_ids[0])
	var summoned := sim.api.state.get_unit(summoned_id)
	assert(summoned != null, "Summoned Aye-Aye Ascetic should exist.")
	assert(_status_stacks(sim, summoned_id, AYE_AYE_THRESHOLD_ID) == 1, "Aye-Aye Ascetic should start armed.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), summoned_id, 4, true)
	assert(_status_stacks(sim, summoned_id, ABSORB_ID) == 1, "Aye-Aye Ascetic should gain Absorb on its first threshold trigger.")
	assert(int(summoned.max_health) == 9 and int(summoned.health) == 5, "Aye-Aye Ascetic should gain +2 full max health after the trigger.")
	assert(_status_stacks(sim, summoned_id, AYE_AYE_THRESHOLD_ID) == -1, "Aye-Aye Ascetic threshold status should consume itself for the round.")
	assert(
		sim.api.get_summon_card_max_health_bonus(String(ctx.card_data.uid)) == 2,
		"Aye-Aye Ascetic should update its reserve card max-health bonus."
	)

	sim.api.plan_intent(summoned_id)
	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	ActionLifecycleSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	assert(_status_stacks(sim, summoned_id, AYE_AYE_THRESHOLD_ID) == 1, "Aye-Aye Ascetic should re-arm at player turn start.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), summoned_id, 2, true)
	assert(int(summoned.max_health) == 11 and int(summoned.health) == 5, "Aye-Aye Ascetic should be able to trigger again next round.")
	assert(
		sim.api.get_summon_card_max_health_bonus(String(ctx.card_data.uid)) == 4,
		"Aye-Aye Ascetic reserve card bonus should accumulate across rounds."
	)

func _verify_entangled_votary() -> void:
	var setup := _make_sim(30)
	var sim := setup.get("sim") as Sim
	var ctx := _play_card(sim, ENTANGLED_VOTARY)
	var summoned_id := int(ctx.summoned_ids[0])
	var summoned := sim.api.state.get_unit(summoned_id)
	assert(_status_stacks(sim, summoned_id, ENTANGLED_GROWTH_ID) == 1, "Entangled Votary should apply its growth status on summon.")

	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	assert(int(summoned.max_health) == 12 and int(summoned.health) == 10, "Entangled Votary should gain +2 empty max health at round end.")
	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	assert(int(summoned.max_health) == 14 and int(summoned.health) == 10, "Entangled Votary should grow again on the next round.")

func _verify_phoenix_brooch() -> void:
	var setup := _make_sim(12)
	var sim := setup.get("sim") as Sim
	var ally_id := int(setup.get("ally_1_id", 0))
	var ally := sim.api.state.get_unit(ally_id)

	_play_card(sim, PHOENIX_BROOCH, ally_id)
	assert(_status_stacks(sim, ally_id, PHOENIX_BROOCH_ID) == 1, "Phoenix Brooch should apply to the targeted ally.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), ally_id, 20, true)
	assert(ally != null and ally.is_alive(), "Phoenix Brooch should prevent the first death.")
	assert(int(ally.health) == int(ally.max_health), "Phoenix Brooch should heal the ally to full.")
	assert(_status_stacks(sim, ally_id, PHOENIX_BROOCH_ID) == -1, "Phoenix Brooch should remove itself after saving the ally.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), ally_id, 20, true)
	assert(!sim.api.is_alive(ally_id), "Phoenix Brooch should only prevent death once.")

func _verify_phoenix_brooch_timeline_sync() -> void:
	var compiler := TurnTimelineCompiler.new()
	var timeline := compiler.compile_actor_turn(_make_phoenix_brooch_resurrection_turn())
	var impact_order = null
	var removal_count := 0
	var saw_heal_event := false

	for beat in timeline.beats:
		if beat == null:
			continue
		for order in beat.orders:
			if order == null:
				continue
			if int(order.kind) == int(PresentationOrder.Kind.IMPACT) and impact_order == null:
				impact_order = order
			elif int(order.kind) == int(PresentationOrder.Kind.REMOVAL):
				removal_count += 1
		for event in beat.events:
			if event != null and int(event.type) == int(BattleEvent.Type.HEAL_APPLIED):
				saw_heal_event = true

	assert(impact_order != null, "Phoenix Brooch resurrection turn should still emit an impact order.")
	assert(int(impact_order.after_health) == 3, "Impact order should reflect the resurrected final health.")
	assert(!bool(impact_order.was_lethal), "Phoenix Brooch resurrection should clear lethal impact presentation.")
	assert(removal_count == 0, "Phoenix Brooch resurrection should not emit a removal presentation order.")
	assert(saw_heal_event, "Phoenix Brooch resurrection timeline should keep the heal event assigned to a beat.")

func _verify_battle_event_log_debug_printer() -> void:
	var heal_event := BattleEvent.new(BattleEvent.Type.HEAL_APPLIED)
	heal_event.data = {
		Keys.SOURCE_ID: 5,
		Keys.TARGET_ID: 5,
		Keys.BEFORE_HEALTH: 0,
		Keys.AFTER_HEALTH: 3,
		Keys.FLAT_AMOUNT: 3,
		Keys.OF_TOTAL: 0.0,
		Keys.OF_MISSING: 0.0,
		Keys.HEALED_AMOUNT: 3,
	}
	var summary := BattleEventLog._fmt_special_event_data(heal_event, heal_event.data, 10, 80)
	assert(summary.contains("hp=0->3"), "Heal debug summary should include the health transition.")
	assert(summary.contains("healed=3"), "Heal debug summary should include healed_amount.")
	assert(summary.contains("flat=3"), "Heal debug summary should include flat heal input.")

	var debug_log := BattleEventLog.new()
	debug_log.append(heal_event)
	BattleEventLog.print_event_log(debug_log, 1, 0, 0.0, true, false, [], true, true, true, false, 10, 80, false)

func _verify_pocket_silkstitchers() -> void:
	var setup := _make_sim(30)
	var sim := setup.get("sim") as Sim
	var ally_id := int(setup.get("ally_1_id", 0))

	_play_card(sim, POCKET_SILKSTITCHERS)
	assert(_status_stacks(sim, int(sim.api.get_player_id()), POCKET_SILKSTITCHERS_ID) == 1, "Pocket Silkstitchers should apply to the player.")
	assert(_status_data_bool(sim, int(sim.api.get_player_id()), POCKET_SILKSTITCHERS_ID, Keys.ARMED), "Pocket Silkstitchers should start armed.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), ally_id, 1, true)
	assert(_status_stacks(sim, ally_id, MIGHT_ID) == 1, "Pocket Silkstitchers should grant Might on the first survived strike.")
	assert(int(sim.api.state.get_unit(ally_id).max_health) == 10, "Pocket Silkstitchers should grant +2 Full Fortitude on the first survived strike.")
	assert(!_status_data_bool(sim, int(sim.api.get_player_id()), POCKET_SILKSTITCHERS_ID, Keys.ARMED), "Pocket Silkstitchers should disarm after triggering.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), ally_id, 1, true)
	assert(_status_stacks(sim, ally_id, MIGHT_ID) == 1, "Pocket Silkstitchers should only trigger once per round.")

	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	assert(_status_data_bool(sim, int(sim.api.get_player_id()), POCKET_SILKSTITCHERS_ID, Keys.ARMED), "Pocket Silkstitchers should re-arm at player turn start.")

	_apply_direct_damage(sim, int(setup.get("enemy_1_id", 0)), ally_id, 1, true)
	assert(_status_stacks(sim, ally_id, MIGHT_ID) == 2, "Pocket Silkstitchers should trigger again after re-arming.")

func _verify_dominion_roster() -> void:
	var setup := _make_sim(30)
	var sim := setup.get("sim") as Sim
	var ally_1_id := int(setup.get("ally_1_id", 0))
	var ally_2_id := int(setup.get("ally_2_id", 0))
	var ally_1 := sim.api.state.get_unit(ally_1_id)
	var ally_2 := sim.api.state.get_unit(ally_2_id)
	ally_1.mortality = CombatantState.Mortality.BOUND
	ally_2.mortality = CombatantState.Mortality.WILD

	_play_card(sim, DOMINION_ROSTER)
	SimStatusSystem.on_actor_turn_end(sim.api, sim.api.get_player_id())
	assert(_status_stacks(sim, ally_1_id, MIGHT_ID) == 2, "Dominion Roster should buff Bound allies.")
	assert(_status_stacks(sim, ally_2_id, MIGHT_ID) == 2, "Dominion Roster should buff Wild allies.")

	setup = _make_sim(30)
	sim = setup.get("sim") as Sim
	ally_1_id = int(setup.get("ally_1_id", 0))
	ally_2_id = int(setup.get("ally_2_id", 0))
	ally_1 = sim.api.state.get_unit(ally_1_id)
	ally_2 = sim.api.state.get_unit(ally_2_id)
	ally_1.mortality = CombatantState.Mortality.BOUND
	ally_2.mortality = CombatantState.Mortality.WILD

	_play_card(sim, DOMINION_ROSTER)
	sim.api.state.turn.card_types_played_this_turn.append(int(CardData.CardType.SOULBOUND))
	SimStatusSystem.on_actor_turn_end(sim.api, sim.api.get_player_id())
	assert(_status_stacks(sim, ally_1_id, MIGHT_ID) == -1, "Dominion Roster should not trigger if a Soulbound card was played.")
	assert(_status_stacks(sim, ally_2_id, MIGHT_ID) == -1, "Dominion Roster should not trigger if a Soulbound card was played.")

func _verify_jabber_collector() -> void:
	var setup := _make_sim(50)
	var sim := setup.get("sim") as Sim
	var ally_1_id := int(setup.get("ally_1_id", 0))
	var ally_2_id := int(setup.get("ally_2_id", 0))
	var ally_1 := sim.api.state.get_unit(ally_1_id)
	ally_1.health = 5

	_play_card(sim, JABBER_COLLECTOR)
	_play_card(sim, MOMENTUM, ally_2_id)
	assert(int(ally_1.health) == 5, "Jabber Collector should not trigger on the first Convocation.")

	_play_card(sim, MOMENTUM, ally_2_id)
	assert(int(ally_1.health) == 8, "Jabber Collector should heal the frontmost ally on the second Convocation.")
	assert(_status_stacks(sim, ally_1_id, BULWARK_ID) == 10, "Jabber Collector should grant Bulwark 10 on the trigger.")

	ally_1.health = 5
	_play_card(sim, MOMENTUM, ally_2_id)
	assert(int(ally_1.health) == 5, "Jabber Collector should only trigger once per round.")

	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	ally_1.health = 5
	_play_card(sim, MOMENTUM, ally_2_id)
	_play_card(sim, MOMENTUM, ally_2_id)
	assert(int(ally_1.health) == 8, "Jabber Collector should reset and trigger again next round.")

func _verify_bulwark() -> void:
	var setup := _make_sim(30)
	var sim := setup.get("sim") as Sim
	var ally_id := int(setup.get("ally_1_id", 0))
	var status_ctx := StatusContext.new()
	status_ctx.source_id = int(sim.api.get_player_id())
	status_ctx.target_id = ally_id
	status_ctx.status_id = BULWARK_ID
	status_ctx.stacks = 100
	status_ctx.reason = "verify_bulwark"
	sim.api.apply_status(status_ctx)
	assert(_status_stacks(sim, ally_id, BULWARK_ID) == 75, "Bulwark should clamp stacks at 75.")

	var token_ctx := StatusTokenContext.new()
	token_ctx.id = BULWARK_ID
	token_ctx.stacks = 999
	var tokens := BULWARK_PROTO.get_modifier_tokens(token_ctx)
	assert(!tokens.is_empty(), "Bulwark should contribute a damage-taken modifier.")
	assert(is_equal_approx(float(tokens[0].mult_value), -0.75), "Bulwark modifier output should cap at 75%.")

	SimStatusSystem.on_player_turn_begin(sim.api, sim.api.get_player_id())
	assert(_status_stacks(sim, ally_id, BULWARK_ID) == -1, "Bulwark should clear at player turn start.")

func _verify_draft_pool() -> void:
	var expected_ids := {
		&"aye_aye_ascetic": true,
		&"entangled_votary": true,
		&"phoenix_brooch": true,
		&"pocket_silkstitchers": true,
		&"dominion_roster": true,
		&"jabber_collector": true,
	}
	for card in COLE_DRAFTABLE_CARDS.cards:
		if card == null:
			continue
		expected_ids.erase(card.id)
	assert(expected_ids.is_empty(), "Cole draft pool is missing one or more new Soulbound/Enchantment cards: %s" % str(expected_ids.keys()))

func _verify_status_catalog() -> void:
	var status_catalog := STATUS_CATALOG_RESOURCE.duplicate(true) as StatusCatalog
	status_catalog.build_index()
	for status_id in [
		AYE_AYE_THRESHOLD_ID,
		ENTANGLED_GROWTH_ID,
		PHOENIX_BROOCH_ID,
		POCKET_SILKSTITCHERS_ID,
		DOMINION_ROSTER_ID,
		JABBER_COLLECTOR_ID,
		BULWARK_ID,
	]:
		assert(status_catalog.get_proto(status_id) != null, "Status catalog should include %s." % String(status_id))

func _make_sim(enemy_health: int) -> Dictionary:
	var status_catalog := STATUS_CATALOG_RESOURCE.duplicate(true) as StatusCatalog
	status_catalog.build_index()

	var sim := Sim.new()
	sim.status_catalog = status_catalog
	sim.init_from_seeds(303, 404)
	sim.runtime.sim = sim

	sim.state.resource.max_mana = 99
	sim.state.resource.mana = 99
	sim.api.writer.allow_unscoped_events = true

	var player := _make_unit(sim.state, "Player", BattleState.FRIENDLY, CombatantView.Type.PLAYER, 30, 0)
	var ally_1 := _make_unit(sim.state, "Ally 1", BattleState.FRIENDLY, CombatantView.Type.ALLY, 8, 4)
	var ally_2 := _make_unit(sim.state, "Ally 2", BattleState.FRIENDLY, CombatantView.Type.ALLY, 6, 3)
	var enemy_1 := _make_unit(sim.state, "Enemy", BattleState.ENEMY, CombatantView.Type.ENEMY, enemy_health, 0)

	sim.state.groups[BattleState.FRIENDLY].player_id = int(player.id)
	sim.api.writer.set_turn_context(1, BattleState.FRIENDLY, int(player.id))

	return {
		"sim": sim,
		"player_id": int(player.id),
		"ally_1_id": int(ally_1.id),
		"ally_2_id": int(ally_2.id),
		"enemy_1_id": int(enemy_1.id),
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

func _play_card(sim: Sim, proto: CardData, target_id: int = 0) -> CardContext:
	var card := proto.make_runtime_instance()
	var ctx := CardContext.new()
	ctx.api = sim.api
	ctx.runtime = sim.runtime
	ctx.source_id = int(sim.api.get_player_id())
	ctx.card_data = card
	if target_id > 0:
		ctx.target_ids = PackedInt32Array([target_id])
	if sim.api.state != null and sim.api.state.turn != null:
		sim.api.state.turn.card_ids_played_this_turn.append(card.id)
		sim.api.state.turn.card_types_played_this_turn.append(int(card.card_type))
	SimStatusSystem.on_card_played(sim.api, int(ctx.source_id), card)
	for action in card.actions:
		assert(action != null and action.activate_sim(ctx), "Card action failed for %s" % String(card.name))
	return ctx

func _apply_direct_damage(sim: Sim, source_id: int, target_id: int, amount: int, strike_damage: bool = false) -> void:
	var damage_ctx := DamageContext.new()
	damage_ctx.source_id = source_id
	damage_ctx.target_id = target_id
	damage_ctx.base_amount = amount
	damage_ctx.reason = "verify_cole_soulbound_enchantment_pack"
	if strike_damage:
		damage_ctx.tags.append(&"strike_damage")
	sim.api.resolve_damage_immediate(damage_ctx)

func _status_stacks(sim: Sim, target_id: int, status_id: StringName) -> int:
	return int(sim.api.get_status_stacks(target_id, status_id))

func _status_data_bool(sim: Sim, target_id: int, status_id: StringName, key: StringName) -> bool:
	var target := sim.api.state.get_unit(target_id) if sim != null and sim.api != null and sim.api.state != null else null
	if target == null or target.statuses == null:
		return false
	var token := target.statuses.get_status_token(status_id, false)
	if token == null or token.data == null:
		return false
	return bool(token.data.get(key, false))

func _make_phoenix_brooch_resurrection_turn() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_BEGIN, 1, 0, Scope.Kind.ACTOR_TURN, {
		Keys.SCOPE_LABEL: "actor=3",
		Keys.ACTOR_ID: 3,
		Keys.GROUP_INDEX: 1,
		Keys.TURN_ID: 2,
	}))
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_BEGIN, 2, 1, Scope.Kind.ATTACK, {
		Keys.SCOPE_LABEL: "attacker=3",
		Keys.ACTOR_ID: 3,
		Keys.GROUP_INDEX: 1,
		Keys.TURN_ID: 2,
	}))
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_BEGIN, 3, 2, Scope.Kind.STRIKE, {
		Keys.SCOPE_LABEL: "i=0",
		Keys.ACTOR_ID: 3,
		Keys.GROUP_INDEX: 1,
		Keys.TURN_ID: 2,
	}))
	var strike_event := _make_event(BattleEvent.Type.STRIKE, {
		Keys.SOURCE_ID: 3,
		Keys.TARGET_IDS: PackedInt32Array([5]),
	}, Scope.Kind.STRIKE, 3, 2)
	strike_event.defines_beat = true
	events.append(strike_event)
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_BEGIN, 4, 3, Scope.Kind.HIT, {
		Keys.SCOPE_LABEL: "t=5",
		Keys.ACTOR_ID: 3,
		Keys.TARGET_ID: 5,
		Keys.GROUP_INDEX: 1,
		Keys.TURN_ID: 2,
	}))
	events.append(_make_event(BattleEvent.Type.DAMAGE_APPLIED, {
		Keys.SOURCE_ID: 3,
		Keys.TARGET_ID: 5,
		Keys.BEFORE_HEALTH: 2,
		Keys.AFTER_HEALTH: 0,
		Keys.BASE_AMOUNT: 2,
		Keys.BASE_BANISH_AMOUNT: 0,
		Keys.FINAL_AMOUNT: 2,
		Keys.DISPLAY_AMOUNT: 2,
		Keys.BANISH_AMOUNT: 0,
		Keys.APPLIED_BANISH_AMOUNT: 0,
		Keys.HEALTH_DAMAGE: 2,
		Keys.WAS_LETHAL: true,
	}, Scope.Kind.HIT, 4, 3))
	events.append(_make_event(BattleEvent.Type.HEAL_APPLIED, {
		Keys.SOURCE_ID: 5,
		Keys.TARGET_ID: 5,
		Keys.BEFORE_HEALTH: 0,
		Keys.AFTER_HEALTH: 3,
		Keys.FLAT_AMOUNT: 3,
		Keys.OF_TOTAL: 0.0,
		Keys.OF_MISSING: 0.0,
		Keys.HEALED_AMOUNT: 3,
	}, Scope.Kind.HIT, 4, 3))
	events.append(_make_event(BattleEvent.Type.STATUS, {
		Keys.SOURCE_ID: 5,
		Keys.TARGET_ID: 5,
		Keys.TARGET_IDS: PackedInt32Array([5]),
		Keys.STATUS_ID: PHOENIX_BROOCH_ID,
		Keys.OP: Status.OP.REMOVE,
		Keys.STACKS: 0,
		Keys.BEFORE_STACKS: 1,
		Keys.AFTER_STACKS: 0,
		Keys.DELTA_STACKS: -1,
	}, Scope.Kind.HIT, 4, 3))
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_END, 4, 3, Scope.Kind.HIT, {
		Keys.SCOPE_LABEL: "t=5",
		Keys.ACTOR_ID: 3,
	}))
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_END, 3, 2, Scope.Kind.STRIKE, {
		Keys.SCOPE_LABEL: "i=0",
		Keys.ACTOR_ID: 3,
	}))
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_END, 2, 1, Scope.Kind.ATTACK, {
		Keys.SCOPE_LABEL: "attacker=3",
		Keys.ACTOR_ID: 3,
	}))
	events.append(_make_scope_event(BattleEvent.Type.SCOPE_END, 1, 0, Scope.Kind.ACTOR_TURN, {
		Keys.SCOPE_LABEL: "actor=3",
		Keys.ACTOR_ID: 3,
	}))
	return _assign_debug_seq(events)

func _make_scope_event(type: int, scope_id: int, parent_scope_id: int, scope_kind: int, data: Dictionary) -> BattleEvent:
	var event := _make_event(type, data, scope_kind, scope_id, parent_scope_id)
	event.data[Keys.SCOPE_ID] = scope_id
	event.data[Keys.PARENT_SCOPE_ID] = parent_scope_id
	event.data[Keys.SCOPE_KIND] = scope_kind
	return event

func _make_event(type: int, data: Dictionary, scope_kind: int = -1, scope_id: int = 0, parent_scope_id: int = 0) -> BattleEvent:
	var event := BattleEvent.new(type)
	event.scope_kind = scope_kind
	event.scope_id = scope_id
	event.parent_scope_id = parent_scope_id
	event.group_index = int(data.get(Keys.GROUP_INDEX, -1))
	event.turn_id = int(data.get(Keys.TURN_ID, 0))
	event.active_actor_id = int(data.get(Keys.ACTOR_ID, 0))
	event.data = data.duplicate(true)
	return event

func _assign_debug_seq(events: Array[BattleEvent]) -> Array[BattleEvent]:
	for i in range(events.size()):
		var event := events[i]
		if event == null:
			continue
		event.seq = 1000 + i
		event.battle_tick = 1000 + i
	return events
