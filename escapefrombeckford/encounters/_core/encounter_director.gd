class_name EncounterDirector extends Node

const EncounterStateScript = preload("res://encounters/_core/encounter_state.gd")
const EncounterCapabilitySetScript = preload("res://encounters/_core/encounter_capability_set.gd")
const EncounterGateRequestScript = preload("res://encounters/_core/encounter_gate_request.gd")
const EncounterDialogueRequestScript = preload("res://encounters/_core/encounter_dialogue_request.gd")
const EncounterRuleContextScript = preload("res://encounters/_core/encounter_rule_context.gd")
const GateResultScript = preload("res://encounters/_core/gate_result.gd")
const EncounterStepScript = preload("res://encounters/_core/encounter_step.gd")

signal step_changed(step_id: StringName)
signal dialogue_requested(request)
signal capabilities_changed(capabilities)
signal gate_denied(result)
signal blocking_state_changed(is_blocking: bool)

var definition = null
var state = EncounterStateScript.new()
var battle = null

func _exit_tree() -> void:
	if Events != null and Events.encounter_observed_event.is_connected(observe_view_event):
		Events.encounter_observed_event.disconnect(observe_view_event)

func setup(owner_battle, data) -> void:
	battle = owner_battle
	definition = data.encounter_definition if data != null else null
	state = EncounterStateScript.new()
	if definition != null and definition.initial_flags != null:
		state.flags = definition.initial_flags.duplicate(true)
	if Events != null and !Events.encounter_observed_event.is_connected(observe_view_event):
		Events.encounter_observed_event.connect(observe_view_event)

func start() -> void:
	if !is_active():
		_emit_capabilities(EncounterCapabilitySetScript.new())
		return
	var first_step_id = definition.initial_step_id
	if first_step_id == &"" and !definition.steps.is_empty() and definition.steps[0] != null:
		first_step_id = definition.steps[0].id
	goto_step(first_step_id)

func is_active() -> bool:
	return definition != null and !definition.steps.is_empty()

func evaluate_gate(req):
	return _evaluate_gate(req, true)

func can_end_turn() -> bool:
	if !is_active():
		return true
	if _is_dialogue_blocking():
		return false
	return state.capabilities != null and state.capabilities.can_end_turn

func can_play_card_ui(card_uid: StringName) -> bool:
	if !is_active():
		return true
	if _is_dialogue_blocking():
		return false
	if state.capabilities == null:
		return true
	return state.capabilities.allows_card_uid(String(card_uid))

func is_blocking_presentation() -> bool:
	return _is_dialogue_blocking()

func get_player_turn_draw_amount_override() -> int:
	var step = get_current_step()
	if step == null:
		return -1
	return int(step.player_turn_draw_amount_override)

func observe_view_event(ev) -> void:
	if !is_active() or ev == null:
		return
	state.last_observed_event = ev
	var ctx = _make_context(null, ev)
	_run_triggers(definition.triggers, ctx)
	var step = get_current_step()
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
	blocking_state_changed.emit(_is_dialogue_blocking())

func queue_dialogue(request) -> void:
	if request == null:
		return
	state.active_dialogue = request
	state.awaiting_dialogue_ack = int(request.mode) == int(EncounterDialogueRequestScript.Mode.BLOCKING)
	_refresh_capabilities_from_current_step()
	blocking_state_changed.emit(_is_dialogue_blocking())
	dialogue_requested.emit(request)

func goto_step(step_id: StringName) -> void:
	if !is_active() or step_id == &"":
		return
	var step = definition.get_step_by_id(step_id)
	if step == null:
		push_warning("EncounterDirector.goto_step(): unknown step '%s'" % String(step_id))
		return
	state.current_step_id = step.id
	step_changed.emit(step.id)
	_refresh_capabilities_from_current_step()
	var ctx = _make_context(null, null)
	ctx.current_step = step
	_run_actions(step.entry_actions, ctx)
	_try_complete_step(ctx)

func set_flag(flag_name: StringName, value: Variant) -> void:
	if flag_name == &"":
		return
	state.flags[flag_name] = value

func get_current_step():
	if !is_active():
		return null
	return definition.get_step_by_id(state.current_step_id)

func _evaluate_gate(req, emit_feedback: bool):
	if !is_active():
		return _make_gate_result(GateResultScript.Verdict.ALLOW)
	if _is_dialogue_blocking():
		var deferred = _make_gate_result(GateResultScript.Verdict.DEFER, &"dialogue_blocking", "Continue the tutorial dialogue first.")
		deferred.dialogue_request = state.active_dialogue
		if emit_feedback:
			_emit_gate_feedback(deferred)
		return deferred

	var capabilities = state.capabilities if state.capabilities != null else EncounterCapabilitySetScript.new()
	var denied := false
	match int(req.kind):
		EncounterGateRequestScript.Kind.END_TURN:
			denied = !capabilities.can_end_turn
		EncounterGateRequestScript.Kind.PLAY_CARD:
			denied = !capabilities.allows_card_uid(String(req.card_uid)) \
				or !capabilities.allows_insert_index(req.insert_index) \
				or !capabilities.allows_target_ids(req.target_ids)
		EncounterGateRequestScript.Kind.OPEN_SWAP, EncounterGateRequestScript.Kind.CONFIRM_SWAP:
			denied = !capabilities.can_swap or !capabilities.allows_target_ids(req.target_ids)
		EncounterGateRequestScript.Kind.OPEN_DISCARD, EncounterGateRequestScript.Kind.CONFIRM_DISCARD:
			denied = !capabilities.can_select_discard
		EncounterGateRequestScript.Kind.OPEN_SUMMON_REPLACE, EncounterGateRequestScript.Kind.CONFIRM_SUMMON_REPLACE:
			denied = !capabilities.can_play_cards \
				or !capabilities.allows_insert_index(req.insert_index) \
				or !capabilities.allows_target_ids(req.target_ids)

	if !denied:
		return _make_gate_result(GateResultScript.Verdict.ALLOW)

	var result = _build_denied_result(req)
	if emit_feedback:
		_emit_gate_feedback(result)
	return result

func _build_denied_result(req):
	var step = get_current_step()
	var default_message := _default_gate_message(req)
	var message := default_message
	if step != null and !step.denied_message_bbcode.is_empty():
		message = step.denied_message_bbcode

	var result = _make_gate_result(GateResultScript.Verdict.DENY, &"encounter_gate", message)
	if step == null:
		return result

	match int(step.denied_presentation):
		EncounterStepScript.DeniedPresentation.HINT:
			return result
		EncounterStepScript.DeniedPresentation.DIALOGUE_INFO, EncounterStepScript.DeniedPresentation.DIALOGUE_BLOCKING:
			var request = EncounterDialogueRequestScript.new()
			request.dialogue_id = StringName("%s:denied" % String(step.id))
			request.mode = EncounterDialogueRequestScript.Mode.INFO
			if int(step.denied_presentation) == int(EncounterStepScript.DeniedPresentation.DIALOGUE_BLOCKING):
				request.mode = EncounterDialogueRequestScript.Mode.BLOCKING
			request.speaker_name = step.denied_speaker_name
			request.portrait_path = step.denied_portrait_path
			request.text_bbcode = message
			request.confirm_text = step.denied_confirm_text
			request.step_id = step.id
			result.dialogue_request = request
			return result
	return result

func _default_gate_message(req) -> String:
	match int(req.kind):
		EncounterGateRequestScript.Kind.END_TURN:
			return "Finish the current tutorial instruction first."
		EncounterGateRequestScript.Kind.PLAY_CARD:
			return "That card action is not available yet."
		EncounterGateRequestScript.Kind.OPEN_SWAP, EncounterGateRequestScript.Kind.CONFIRM_SWAP:
			return "Swapping is not available right now."
		EncounterGateRequestScript.Kind.OPEN_DISCARD, EncounterGateRequestScript.Kind.CONFIRM_DISCARD:
			return "Discarding is not available right now."
		EncounterGateRequestScript.Kind.OPEN_SUMMON_REPLACE, EncounterGateRequestScript.Kind.CONFIRM_SUMMON_REPLACE:
			return "Choose a tutorial-approved position first."
	return "That action is not available right now."

func _emit_gate_feedback(result) -> void:
	if result == null:
		return
	if result.dialogue_request != null:
		queue_dialogue(result.dialogue_request)
		return
	gate_denied.emit(result)

func _refresh_capabilities_from_current_step() -> void:
	var next_caps = EncounterCapabilitySetScript.new()
	var step = get_current_step()
	if step != null and step.capability_overrides != null:
		next_caps = step.capability_overrides.clone()
	if step != null and step.block_input_while_dialogue and _is_dialogue_blocking():
		next_caps.presentation_locked = true
		next_caps.can_end_turn = false
		next_caps.can_play_cards = false
		next_caps.can_swap = false
		next_caps.can_select_discard = false
	state.capabilities = next_caps
	_emit_capabilities(next_caps)

func _make_gate_result(verdict: int, reason_id: StringName = &"", message := ""):
	var result = GateResultScript.new()
	result.verdict = verdict
	result.reason_id = reason_id
	result.player_message = message
	return result

func _emit_capabilities(caps) -> void:
	capabilities_changed.emit(caps)

func _is_dialogue_blocking() -> bool:
	return state != null and state.awaiting_dialogue_ack and state.active_dialogue != null

func _make_context(req, ev):
	var ctx = EncounterRuleContextScript.new()
	ctx.director = self
	ctx.state = state
	ctx.definition = definition
	ctx.battle = battle
	ctx.current_step = get_current_step()
	ctx.gate_request = req
	ctx.observed_event = ev
	return ctx

func _run_triggers(triggers: Array, ctx) -> void:
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

func _run_actions(actions: Array, ctx) -> void:
	for action in actions:
		if action == null:
			continue
		action.execute(ctx)

func _conditions_match(conditions: Array, ctx) -> bool:
	if conditions.is_empty():
		return false
	for condition in conditions:
		if condition == null:
			continue
		if !condition.evaluate(ctx):
			return false
	return true

func _try_complete_step(ctx) -> void:
	var step = get_current_step()
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
