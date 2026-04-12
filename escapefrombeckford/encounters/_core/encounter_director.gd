class_name EncounterDirector extends Node

signal step_changed(step_id: StringName)
signal dialogue_requested(request: EncounterDialogueRequest)
signal capabilities_changed(capabilities: EncounterCapabilitySet)
signal gate_denied(result: GateResult)
signal blocking_state_changed(is_blocking: bool)

var definition: EncounterDefinition = null
var state: EncounterState = EncounterState.new()
var battle: Battle = null
var _step_timer_generation: int = 0

func _exit_tree() -> void:
	_invalidate_step_timer()
	if Events != null and Events.encounter_observed_event.is_connected(observe_view_event):
		Events.encounter_observed_event.disconnect(observe_view_event)

func setup(owner_battle: Battle, data: BattleData) -> void:
	battle = owner_battle
	definition = data.encounter_definition if data != null else null
	state = EncounterState.new()
	if definition != null and definition.initial_flags != null:
		state.flags = definition.initial_flags.duplicate(true)
	if Events != null and !Events.encounter_observed_event.is_connected(observe_view_event):
		Events.encounter_observed_event.connect(observe_view_event)

func start() -> void:
	if !is_active():
		_emit_capabilities(EncounterCapabilitySet.new())
		return
	var first_step_id: StringName = definition.initial_step_id
	if first_step_id == &"" and !definition.steps.is_empty() and definition.steps[0] != null:
		first_step_id = definition.steps[0].id
	goto_step(first_step_id)

func is_active() -> bool:
	return definition != null and !definition.steps.is_empty()

func evaluate_gate(req: EncounterGateRequest) -> GateResult:
	return _evaluate_gate(req, true)

func can_end_turn() -> bool:
	if !is_active():
		return true
	if _is_dialogue_blocking():
		return false
	return state.capabilities != null and state.capabilities.can_end_turn

func can_play_card_ui(card_id: StringName) -> bool:
	if !is_active():
		return true
	if _is_dialogue_blocking():
		return false
	if state.capabilities == null:
		return true
	return state.capabilities.allows_card_id(card_id)

func is_blocking_presentation() -> bool:
	return _is_dialogue_blocking()

func get_player_turn_draw_amount_override() -> int:
	var step = get_current_step()
	if step == null:
		return -1
	return int(step.player_turn_draw_amount_override)

func observe_view_event(ev: EncounterObservedEvent) -> void:
	if !is_active() or ev == null:
		return
	_process_observed_event(ev)

func _process_observed_event(ev: EncounterObservedEvent) -> void:
	if !is_active() or ev == null:
		return
	state.last_observed_event = ev
	var ctx: EncounterRuleContext = _make_context(null, ev)
	_run_triggers(definition.triggers, ctx)
	var step: EncounterStep = get_current_step()
	if step != null:
		ctx.current_step = step
		_run_triggers(step.triggers, ctx)
		_try_complete_step(ctx)

func acknowledge_dialogue(dialogue_id: StringName) -> void:
	if state.active_dialogue == null:
		return
	if dialogue_id != &"" and state.active_dialogue.dialogue_id != dialogue_id:
		return
	state.active_dialogue = null
	state.awaiting_dialogue_ack = false
	_refresh_capabilities_from_current_step()
	var ack_event: EncounterObservedEvent = EncounterObservedEvent.new()
	ack_event.name = &"dialogue_acknowledged"
	ack_event.data = {
		"dialogue_id": dialogue_id,
	}
	_process_observed_event(ack_event)
	blocking_state_changed.emit(_is_dialogue_blocking())

func queue_dialogue(request: EncounterDialogueRequest) -> void:
	if request == null:
		return
	state.active_dialogue = request
	state.awaiting_dialogue_ack = int(request.mode) == int(EncounterDialogueRequest.Mode.BLOCKING)
	_refresh_capabilities_from_current_step()
	blocking_state_changed.emit(_is_dialogue_blocking())
	dialogue_requested.emit(request)

func goto_step(step_id: StringName) -> void:
	if !is_active() or step_id == &"":
		return
	_invalidate_step_timer()
	var step: EncounterStep = definition.get_step_by_id(step_id)
	if step == null:
		push_warning("EncounterDirector.goto_step(): unknown step '%s'" % String(step_id))
		return
	state.current_step_id = step.id
	step_changed.emit(step.id)
	_refresh_capabilities_from_current_step()
	var ctx: EncounterRuleContext = _make_context(null, null)
	ctx.current_step = step
	_run_actions(step.entry_actions, ctx)
	_try_complete_step(ctx)
	if state.current_step_id != step.id:
		return
	_start_step_auto_advance(step)

func set_flag(flag_name: StringName, value: Variant) -> void:
	if flag_name == &"":
		return
	state.flags[flag_name] = value

func get_current_step() -> EncounterStep:
	if !is_active():
		return null
	return definition.get_step_by_id(state.current_step_id)

func _evaluate_gate(req: EncounterGateRequest, emit_feedback: bool) -> GateResult:
	if !is_active():
		return _make_gate_result(GateResult.Verdict.ALLOW)
	if _is_dialogue_blocking():
		var deferred: GateResult = _make_gate_result(GateResult.Verdict.DEFER, &"dialogue_blocking", "Continue the tutorial dialogue first.")
		deferred.dialogue_request = state.active_dialogue
		if emit_feedback:
			_emit_gate_feedback(deferred)
		return deferred

	var capabilities: EncounterCapabilitySet = state.capabilities if state.capabilities != null else EncounterCapabilitySet.new()
	var denied := false
	match int(req.kind):
		EncounterGateRequest.Kind.END_TURN:
			denied = !capabilities.can_end_turn
		EncounterGateRequest.Kind.PLAY_CARD:
			denied = !capabilities.allows_card_id(req.card_id) \
				or !capabilities.allows_insert_index(req.insert_index) \
				or !capabilities.allows_target_ids(req.target_ids)
		EncounterGateRequest.Kind.OPEN_SWAP, EncounterGateRequest.Kind.CONFIRM_SWAP:
			denied = !capabilities.can_swap or !capabilities.allows_target_ids(req.target_ids)
		EncounterGateRequest.Kind.OPEN_DISCARD, EncounterGateRequest.Kind.CONFIRM_DISCARD:
			denied = !capabilities.can_select_discard
		EncounterGateRequest.Kind.OPEN_SUMMON_REPLACE, EncounterGateRequest.Kind.CONFIRM_SUMMON_REPLACE:
			denied = !capabilities.can_play_cards \
				or !capabilities.allows_insert_index(req.insert_index) \
				or !capabilities.allows_target_ids(req.target_ids)

	if !denied:
		return _make_gate_result(GateResult.Verdict.ALLOW)

	var result: GateResult = _build_denied_result(req)
	if emit_feedback:
		_emit_gate_feedback(result)
	return result

func _build_denied_result(req: EncounterGateRequest) -> GateResult:
	var step: EncounterStep = get_current_step()
	var default_message := _default_gate_message(req)
	var message := default_message
	if step != null and !step.denied_message_bbcode.is_empty():
		message = step.denied_message_bbcode

	var result: GateResult = _make_gate_result(GateResult.Verdict.DENY, &"encounter_gate", message)
	if step == null:
		return result

	match int(step.denied_presentation):
		EncounterStep.DeniedPresentation.HINT:
			return result
		EncounterStep.DeniedPresentation.DIALOGUE_INFO, EncounterStep.DeniedPresentation.DIALOGUE_BLOCKING:
			var request: EncounterDialogueRequest = EncounterDialogueRequest.new()
			request.dialogue_id = StringName("%s:denied" % String(step.id))
			request.mode = EncounterDialogueRequest.Mode.INFO
			if int(step.denied_presentation) == int(EncounterStep.DeniedPresentation.DIALOGUE_BLOCKING):
				request.mode = EncounterDialogueRequest.Mode.BLOCKING
			request.speaker_name = step.denied_speaker_name
			request.portrait_path = step.denied_portrait_path
			request.text_bbcode = message
			request.confirm_text = step.denied_confirm_text
			request.step_id = step.id
			result.dialogue_request = request
			return result
	return result

func _default_gate_message(req: EncounterGateRequest) -> String:
	match int(req.kind):
		EncounterGateRequest.Kind.END_TURN:
			return "Finish the current tutorial instruction first."
		EncounterGateRequest.Kind.PLAY_CARD:
			return "That card action is not available yet."
		EncounterGateRequest.Kind.OPEN_SWAP, EncounterGateRequest.Kind.CONFIRM_SWAP:
			return "Swapping is not available right now."
		EncounterGateRequest.Kind.OPEN_DISCARD, EncounterGateRequest.Kind.CONFIRM_DISCARD:
			return "Discarding is not available right now."
		EncounterGateRequest.Kind.OPEN_SUMMON_REPLACE, EncounterGateRequest.Kind.CONFIRM_SUMMON_REPLACE:
			return "Choose a tutorial-approved position first."
	return "That action is not available right now."

func _emit_gate_feedback(result: GateResult) -> void:
	if result == null:
		return
	if result.dialogue_request != null:
		queue_dialogue(result.dialogue_request)
		return
	gate_denied.emit(result)

func _refresh_capabilities_from_current_step() -> void:
	var next_caps: EncounterCapabilitySet = EncounterCapabilitySet.new()
	var step: EncounterStep = get_current_step()
	if step != null and step.capability_overrides != null:
		next_caps = step.capability_overrides.clone() as EncounterCapabilitySet
	if step != null and step.block_input_while_dialogue and _is_dialogue_blocking():
		next_caps.presentation_locked = true
		next_caps.can_end_turn = false
		next_caps.can_play_cards = false
		next_caps.can_swap = false
		next_caps.can_select_discard = false
	state.capabilities = next_caps
	_emit_capabilities(next_caps)

func _make_gate_result(verdict: int, reason_id: StringName = &"", message := "") -> GateResult:
	var result: GateResult = GateResult.new()
	result.verdict = verdict
	result.reason_id = reason_id
	result.player_message = message
	return result

func _emit_capabilities(caps: EncounterCapabilitySet) -> void:
	capabilities_changed.emit(caps)

func _is_dialogue_blocking() -> bool:
	return state != null and state.awaiting_dialogue_ack and state.active_dialogue != null

func _invalidate_step_timer() -> void:
	_step_timer_generation += 1

func _start_step_auto_advance(step: EncounterStep) -> void:
	if step == null:
		return
	if float(step.auto_advance_after_sec) < 0.0:
		return
	if step.next_step_id == &"" or step.next_step_id == step.id:
		return
	var tree: SceneTree = battle.get_tree() if battle != null else get_tree()
	if tree == null:
		return
	var generation := _step_timer_generation
	_wait_for_step_auto_advance(StringName(step.id), StringName(step.next_step_id), float(step.auto_advance_after_sec), generation)

func _wait_for_step_auto_advance(from_step_id: StringName, to_step_id: StringName, delay_sec: float, generation: int) -> void:
	if delay_sec <= 0.0:
		if generation == _step_timer_generation and state.current_step_id == from_step_id:
			goto_step(to_step_id)
		return
	var tree: SceneTree = battle.get_tree() if battle != null else get_tree()
	if tree == null:
		return
	await tree.create_timer(delay_sec, false).timeout
	if generation != _step_timer_generation:
		return
	if !is_active() or state.current_step_id != from_step_id:
		return
	goto_step(to_step_id)

func _make_context(req: EncounterGateRequest, ev: EncounterObservedEvent) -> EncounterRuleContext:
	var ctx: EncounterRuleContext = EncounterRuleContext.new()
	ctx.director = self
	ctx.state = state
	ctx.definition = definition
	ctx.battle = battle
	ctx.current_step = get_current_step()
	ctx.gate_request = req
	ctx.observed_event = ev
	return ctx

func _run_triggers(triggers: Array[EncounterTrigger], ctx: EncounterRuleContext) -> void:
	for trigger in triggers:
		if trigger == null:
			continue
		var trigger_key := StringName("%s:%s" % [String(ctx.get_current_step_id()), String(trigger.id)])
		if bool(trigger.once) and state.consumed_trigger_ids.get(trigger_key, false):
			continue
		if !_conditions_match(trigger.conditions, ctx):
			continue
		if bool(trigger.once):
			state.consumed_trigger_ids[trigger_key] = true
		_run_actions(trigger.actions, ctx)

func _run_actions(actions: Array[EncounterAction], ctx: EncounterRuleContext) -> void:
	for action in actions:
		if action == null:
			continue
		action.execute(ctx)

func _conditions_match(conditions: Array[EncounterCondition], ctx: EncounterRuleContext) -> bool:
	if conditions.is_empty():
		return false
	for condition in conditions:
		if condition == null:
			continue
		if !condition.evaluate(ctx):
			return false
	return true

func _try_complete_step(ctx: EncounterRuleContext) -> void:
	var step: EncounterStep = get_current_step()
	if step == null or step.completion_conditions.is_empty():
		return
	ctx.current_step = step
	for condition in step.completion_conditions:
		if condition == null:
			continue
		if !condition.evaluate(ctx):
			return
	_run_actions(step.on_complete_actions, ctx)
	if step.next_step_id != &"" and step.next_step_id != step.id:
		goto_step(step.next_step_id)
