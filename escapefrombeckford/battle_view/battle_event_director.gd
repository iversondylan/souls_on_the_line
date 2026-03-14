# battle_event_director.gd

class_name BattleEventDirector extends RefCounted

var battle_view: BattleView
var click: Sound

@export var spawn_pause_sec: float = 0.04
@export var summon_pause_sec: float = 0.06
@export var hit_pause_sec: float = 0.05


func bind(new_battle_view: BattleView) -> void:
	battle_view = new_battle_view
	click = battle_view.click_sound


func on_director_action(a: DirectorAction, gen: int) -> void:
	if a == null or battle_view == null:
		return
	if !battle_view._playing or gen != battle_view._playback_gen:
		return
	print("DIRECTOR ", a.label, " at ", battle_view.clock.now_sec())
	match a.phase:
		DirectorAction.Phase.FOCUS:
			_play_focus_action(a)
		DirectorAction.Phase.WINDUP:
			_play_windup_action(a)
		DirectorAction.Phase.FOLLOWTHROUGH:
			_play_followthrough_action(a)
		DirectorAction.Phase.RESOLVE:
			_play_resolve_action(a)

func _as_attack_info(a: DirectorAction) -> AttackPresentationInfo:
	if a == null:
		return null
	return a.presentation as AttackPresentationInfo

func _make_epkg_from_event(event: BattleEvent, duration: float) -> EventPackage:
	var epkg := EventPackage.new()
	epkg.event = event
	epkg.duration = duration
	return epkg

func _make_status_applied_order(e: EventPackage) -> StatusAppliedOrder:
	var o := StatusAppliedOrder.new()
	o.duration = e.duration
	o.source_id = int(e.event.data.get(Keys.SOURCE_ID, 0))
	o.target_id = int(e.event.data.get(Keys.TARGET_ID, 0))
	o.status_id = e.event.data.get(Keys.STATUS_ID, &"")
	o.intensity = int(e.event.data.get(Keys.INTENSITY, 1))
	o.turns_duration = int(e.event.data.get(Keys.DURATION, 0))
	return o


func _make_status_removed_order(e: EventPackage) -> StatusRemovedOrder:
	var o := StatusRemovedOrder.new()
	o.duration = e.duration
	o.source_id = int(e.event.data.get(Keys.SOURCE_ID, 0))
	o.target_id = int(e.event.data.get(Keys.TARGET_ID, 0))
	o.status_id = e.event.data.get(Keys.STATUS_ID, &"")
	o.intensity = int(e.event.data.get(Keys.INTENSITY, 1))

	#var removed_all := bool(e.event.data.get(Keys.REMOVED_ALL, false))
	#if !removed_all:
		#removed_all = int(e.event.data.get(Keys.INTENSITY, 0)) <= 0 and int(e.event.data.get(Keys.DURATION, 0)) <= 0
	o.removed_all = true

	return o

func play_raw_chunk(pkg: BeatPackage) -> void:
	if pkg == null or pkg.beat.is_empty():
		return
	if battle_view == null:
		return
	if !battle_view._playing or pkg.gen != battle_view._playback_gen:
		return

	if pkg.wait_quarters > 0.0:
		SFXPlayer.play(click)

	for e in pkg.beat:
		if e == null:
			continue
		var epkg := EventPackage.new()
		epkg.event = e
		epkg.duration = pkg.duration_sec
		on_event(epkg)


func _play_focus_action(a: DirectorAction) -> void:
	if a == null:
		return

	var attack_info := _as_attack_info(a)

	match a.action_kind:
		DirectorAction.ActionKind.MELEE_STRIKE, DirectorAction.ActionKind.RANGED_STRIKE:
			if attack_info != null:
				_on_attack_prep_from_info(attack_info, a.duration_sec)
				return

		DirectorAction.ActionKind.SUMMON, DirectorAction.ActionKind.STATUS:
			if a.event != null:
				_on_attack_prep(_make_epkg_from_event(a.event, a.duration_sec))
				return


func _play_windup_action(a: DirectorAction) -> void:
	if a == null:
		return

	var attack_info := _as_attack_info(a)

	match a.action_kind:
		DirectorAction.ActionKind.MELEE_STRIKE, DirectorAction.ActionKind.RANGED_STRIKE:
			if attack_info != null:
				_on_strike_windup_from_info(attack_info, a.duration_sec)
				return

		DirectorAction.ActionKind.SUMMON:
			if a.event != null:
				_on_summon_windup(_make_epkg_from_event(a.event, a.duration_sec))
				return

		DirectorAction.ActionKind.STATUS:
			if a.event != null:
				_on_attack_prep(_make_epkg_from_event(a.event, a.duration_sec))
				return


func _play_followthrough_action(a: DirectorAction) -> void:
	if a == null:
		return

	var attack_info := _as_attack_info(a)

	match a.action_kind:
		DirectorAction.ActionKind.MELEE_STRIKE, DirectorAction.ActionKind.RANGED_STRIKE:
			if attack_info != null:
				_on_strike_followthrough_from_info(attack_info, a.duration_sec)
				_on_attack_wrapup_from_info(attack_info, minf(a.duration_sec, 0.15))
				return

		DirectorAction.ActionKind.SUMMON:
			if a.event != null:
				_on_summon_followthrough(_make_epkg_from_event(a.event, a.duration_sec))
				return

		DirectorAction.ActionKind.STATUS:
			if a.event != null:
				_on_status_changed(_make_epkg_from_event(a.event, a.duration_sec))
				return

	# fallback old payload behavior if needed
	if a.payload.is_empty():
		return

	for e in a.payload:
		var be := e as BattleEvent
		if be == null:
			continue

		var epkg := _make_epkg_from_event(be, a.duration_sec)

		match int(be.type):
			BattleEvent.Type.DAMAGE_APPLIED:
				_on_damage_applied(epkg)
			BattleEvent.Type.STATUS:
				_on_status_changed(epkg)
			BattleEvent.Type.SET_INTENT:
				_on_set_intent(epkg)
			BattleEvent.Type.TURN_STATUS:
				_on_turn_status(epkg)
			BattleEvent.Type.MOVED:
				_on_moved(epkg)


func _play_resolve_action(a: DirectorAction) -> void:
	if a == null:
		return

	if !a.payload.is_empty():
		for e in a.payload:
			var be := e as BattleEvent
			if be == null:
				continue

			var epkg := _make_epkg_from_event(be, a.duration_sec)

			match int(be.type):
				BattleEvent.Type.STATUS:
					_on_status_changed(epkg)

	battle_view.clear_focus(a.duration_sec)

func _action_kind_for_event(e: BattleEvent) -> int:
	if e == null:
		return DirectorAction.ActionKind.GENERIC

	match int(e.type):
		BattleEvent.Type.SUMMONED:
			return DirectorAction.ActionKind.SUMMON
		BattleEvent.Type.STATUS:
			return DirectorAction.ActionKind.STATUS
		BattleEvent.Type.STRIKE:
			var mode := int(e.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE)) if e.data != null else Attack.Mode.MELEE
			if mode == int(Attack.Mode.RANGED):
				return DirectorAction.ActionKind.RANGED_STRIKE
			return DirectorAction.ActionKind.MELEE_STRIKE
		_:
			return DirectorAction.ActionKind.GENERIC

func on_event(e: EventPackage) -> void:
	if e == null or e.event == null or battle_view == null:
		return

	match int(e.event.type):
		BattleEvent.Type.SPAWNED:
			_on_spawned(e)
		BattleEvent.Type.SUMMONED:
			_on_summoned(e)
		BattleEvent.Type.FORMATION_SET:
			_on_formation_set(e)
		BattleEvent.Type.MOVED:
			_on_moved(e)
		BattleEvent.Type.TARGETED:
			_on_targeted(e)
		BattleEvent.Type.DAMAGE_APPLIED:
			_on_damage_applied(e)
		BattleEvent.Type.STATUS, BattleEvent.Type.STATUS_CHANGED:
			_on_status_changed(e)
		BattleEvent.Type.DIED:
			_on_died(e)
		BattleEvent.Type.SET_INTENT:
			_on_set_intent(e)
		BattleEvent.Type.SCOPE_BEGIN:
			_on_scope_begin(e)
		BattleEvent.Type.SCOPE_END:
			_on_scope_end(e)
		BattleEvent.Type.TURN_STATUS:
			_on_turn_status(e)
		BattleEvent.Type.PLAYER_INPUT_REACHED:
			Events.request_draw_hand.emit()
		BattleEvent.Type.END_TURN_PRESSED:
			Events.player_turn_completed.emit()
		BattleEvent.Type.DISCARD_REQUESTED:
			_on_discard_requested(e)
		BattleEvent.Type.FADED:
			_on_faded(e)
		BattleEvent.Type.SUMMON_RESERVE_RELEASED:
			_on_summon_reserve_released(e)
		_:
			pass


func _on_spawned(e: EventPackage) -> void:
	var cid := int(e.event.data.get(Keys.SPAWNED_ID, 0))
	var g := int(e.event.data.get(Keys.GROUP_INDEX, e.event.group_index))
	var idx := int(e.event.data.get(Keys.INSERT_INDEX, -1))
	var is_player := bool(e.event.data.get(Keys.IS_PLAYER, false))
	var after_ids: PackedInt32Array = e.event.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())

	var v := battle_view.get_or_create_combatant_view(cid, g, idx, false, is_player)
	if v == null:
		return

	var spec: Dictionary = e.event.data.get(Keys.SUMMON_SPEC, {})
	v.apply_spawn_spec(spec)

	var ctx := GroupLayoutOrder.new()
	ctx.group_index = g
	ctx.order = after_ids
	ctx.animate_to_position = false
	battle_view.set_group_order(ctx)


func _on_turn_status(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var active_id := int(d.get(Keys.ACTIVE_ID, 0))
	var pending_ids: PackedInt32Array = d.get(Keys.PENDING_IDS, PackedInt32Array())

	var pending_set := {}
	for cid in pending_ids:
		pending_set[int(cid)] = true

	for v: CombatantView in battle_view.get_all_combatant_views():
		if v == null or !is_instance_valid(v):
			continue
		if !v.is_alive:
			v.set_pending_turn_glow(CombatantView.TurnStatus.NONE)
			continue

		if int(v.cid) == active_id:
			v.set_pending_turn_glow(CombatantView.TurnStatus.TURN_ACTIVE)
		elif pending_set.has(int(v.cid)):
			v.set_pending_turn_glow(CombatantView.TurnStatus.TURN_PENDING)
		else:
			v.set_pending_turn_glow(CombatantView.TurnStatus.NONE)


func _on_formation_set(e: EventPackage) -> void:
	var g0: Array = e.event.data.get(Keys.GROUP_0, [])
	var g1: Array = e.event.data.get(Keys.GROUP_1, [])

	var ctx0 := GroupLayoutOrder.new()
	ctx0.group_index = 0
	ctx0.order = g0
	ctx0.animate_to_position = false

	var ctx1 := GroupLayoutOrder.new()
	ctx1.group_index = 1
	ctx1.order = g1
	ctx1.animate_to_position = false

	battle_view.set_group_order(ctx0)
	battle_view.set_group_order(ctx1)


func _on_attack_prep(e: EventPackage) -> void:
	var src := int(e.event.data.get(Keys.SOURCE_ID, 0))
	var targets: Array = e.event.data.get(Keys.TARGET_IDS, [])

	var order := FocusOrder.new()
	order.duration = e.duration
	order.attacker_id = src
	order.target_ids = targets
	order.dim_bg = 0.6
	order.dim_uninvolved = 0.55
	order.scale_involved = 1.08
	order.scale_uninvolved = 1.0
	order.drift_involved = 20.0

	battle_view.apply_focus(order)


func _on_attack_wrapup(e: EventPackage) -> void:
	battle_view.clear_focus(e.duration)

	var src := int(e.event.data.get(Keys.SOURCE_ID, 0))
	var attacker := battle_view.get_combatant(src)
	if attacker != null:
		attacker.clear_strike_pose(e.duration)

	var projectile := battle_view.take_projectile(src)
	if projectile != null and is_instance_valid(projectile):
		projectile.queue_free()


func _on_strike_windup(e: EventPackage) -> void:
	var src := int(e.event.data.get(Keys.SOURCE_ID, 0))
	var targets: Array = e.event.data.get(Keys.TARGET_IDS, [])
	var attacker := battle_view.get_combatant(src)
	if attacker == null:
		return

	var o := StrikeWindupOrder.new()
	o.duration = e.duration
	o.attacker_id = src
	o.target_ids = targets
	o.attack_mode = int(e.event.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))
	o.projectile_scene_path = String(e.event.data.get(Keys.PROJECTILE_SCENE, "res://VFX/projectiles/fireball/fireball.tscn"))

	attacker.play_strike_windup(o, battle_view)


func _on_strike_followthrough(e: EventPackage) -> void:
	var src := int(e.event.data.get(Keys.SOURCE_ID, 0))
	var targets: Array = e.event.data.get(Keys.TARGET_IDS, [])
	var attacker := battle_view.get_combatant(src)
	if attacker == null:
		return

	var o := StrikeFollowthroughOrder.new()
	o.duration = e.duration
	o.attacker_id = src
	o.target_ids = targets
	o.attack_mode = int(e.event.data.get(Keys.ATTACK_MODE, Attack.Mode.MELEE))

	attacker.play_strike_followthrough(o, battle_view)


func _on_moved(e: EventPackage) -> void:
	var after_ids: PackedInt32Array = e.event.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	var g := int(e.event.group_index)

	if after_ids is PackedInt32Array:
		var arr: Array = []
		arr.resize(after_ids.size())
		for i in range(after_ids.size()):
			arr[i] = int(after_ids[i])

		var ctx := GroupLayoutOrder.new()
		ctx.group_index = g
		ctx.order = arr
		ctx.animate_to_position = true
		battle_view.set_group_order(ctx)


func _on_targeted(e: EventPackage) -> void:
	var src := int(e.event.data.get(Keys.SOURCE_ID, 0))
	var targets: Array = e.event.data.get(Keys.TARGET_IDS, [])
	var combatant := battle_view.get_combatant(src)

	if combatant != null:
		combatant.play_targeting()

	for tid in targets:
		var tv := battle_view.get_combatant(int(tid))
		if tv != null:
			tv.show_targeted(true)


func _on_damage_applied(e: EventPackage) -> void:
	var tid := int(e.event.data.get(Keys.TARGET_ID, 0))
	var amount := int(e.event.data.get(Keys.FINAL_AMOUNT, 0))
	var lethal := bool(e.event.data.get(Keys.WAS_LETHAL, false))
	var after_health := int(e.event.data.get(Keys.AFTER_HEALTH, 1))
	var target_combatant := battle_view.get_combatant(tid)

	if target_combatant != null:
		target_combatant.play_hit()
		target_combatant.set_health(after_health, lethal)
		target_combatant.pop_damage_number(amount)


func _on_status_changed(e: EventPackage) -> void:
	if e == null or e.event == null:
		return

	var d := e.event.data if e.event.data != null else {}
	var op := int(d.get(Keys.OP, 0))
	var target_id := int(d.get(Keys.TARGET_ID, 0))
	var target := battle_view.get_combatant(target_id)
	if target == null or target.status_view_grid == null:
		return

	if op == int(Status.OP.REMOVE):
		var ro := _make_status_removed_order(e)
		target.status_view_grid.remove_status(ro)
		return

	# APPLY and CHANGE both update the view to the resolved SIM state.
	var ao := _make_status_applied_order(e)
	target.status_view_grid.apply_status(ao)


func _on_set_intent(e: EventPackage) -> void:
	var cid := int(e.event.data.get(Keys.ACTOR_ID, e.event.active_actor_id))
	var planned_idx := int(e.event.data.get(Keys.PLANNED_IDX, -1))
	var icon_uid := String(e.event.data.get(Keys.INTENT_ICON_UID, ""))
	var icon_ranged_uid := String(e.event.data.get(Keys.INTENT_ICON_RANGED_UID, ""))
	var intent_text := String(e.event.data.get(Keys.INTENT_TEXT, ""))
	var tooltip_text := String(e.event.data.get(Keys.TOOLTIP_TEXT, ""))
	var is_ranged := bool(e.event.data.get(Keys.IS_RANGED, false))

	var cv := battle_view.get_combatant(cid)
	if cv == null:
		return

	if cv.intent_container != null:
		cv.intent_container.apply_intent(planned_idx, icon_uid, icon_ranged_uid, is_ranged, intent_text, tooltip_text)


func _on_died(e: EventPackage) -> void:
	var dead_id := int(e.event.data.get(Keys.TARGET_ID, 0))
	if dead_id <= 0:
		return

	var v := battle_view.get_combatant(dead_id)
	if v != null:
		v.queue_free()

	battle_view.combatants_by_cid.erase(dead_id)


func _on_death_windup(e: EventPackage) -> void:
	var dead_id := int(e.event.data.get(Keys.TARGET_ID, 0))
	if dead_id <= 0:
		return

	var target := battle_view.get_combatant(dead_id)
	if target == null:
		return

	var o := DeathWindupOrder.new()
	o.duration = e.duration
	o.dead_id = dead_id
	o.to_black = true
	o.black_amount = 1.0
	o.shrink = 0.96
	o.slump_px = 10.0

	target.play_death_windup(o)


func _on_death_followthrough(e: EventPackage) -> void:
	var dead_id := int(e.event.data.get(Keys.TARGET_ID, 0))
	var g := int(e.event.data.get(Keys.GROUP_INDEX, e.event.group_index))
	var after_ids: PackedInt32Array = e.event.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dead_view := battle_view.get_combatant(dead_id)
	if dead_view != null:
		dead_view.on_death_followthrough(e.duration)

	if after_ids.size() > 0:
		var arr: Array = []
		arr.resize(after_ids.size())
		for i in range(after_ids.size()):
			arr[i] = int(after_ids[i])

		var ctx := GroupLayoutOrder.new()
		ctx.group_index = g
		ctx.order = arr
		ctx.animate_to_position = true
		battle_view.set_group_order(ctx)


func _on_discard_requested(e: EventPackage) -> void:
	if e == null:
		return
	var d: Dictionary = e.event.data if e.event.data != null else {}

	var ctx := DiscardContext.new()
	ctx.source_id = int(d.get(Keys.SOURCE_ID, 0))
	ctx.amount = int(d.get(Keys.AMOUNT, 0))
	ctx.card_uid = String(d.get(Keys.CARD_UID, ""))

	var sim_host: SimHost = battle_view.sim_host if battle_view != null else null
	ctx.on_done = func(chosen_uids: Array[String]) -> void:
		if sim_host == null:
			push_warning("DiscardContext.on_done: missing sim_host")
			return
		var api := sim_host.get_main_api()
		if api == null:
			push_warning("DiscardContext.on_done: missing sim api")
			return
		api.resolve_player_discard(chosen_uids)

	Events.request_discard_cards.emit(ctx)


func _on_fade_windup(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var dead_id := int(d.get(Keys.TARGET_ID, 0))
	var v := battle_view.get_combatant(dead_id)
	if v == null or v.character_art == null:
		return

	if v.tween_misc:
		v.tween_misc.kill()
	v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	v.tween_misc.tween_property(v.character_art, "modulate:a", 0.0, maxf(e.duration, 0.01))


func _on_fade_followthrough(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var dead_id := int(d.get(Keys.TARGET_ID, 0))
	var g := int(d.get(Keys.GROUP_INDEX, e.event.group_index))
	var after_ids: PackedInt32Array = d.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dv := battle_view.get_combatant(dead_id)
	if dv != null:
		dv.is_alive = false

	if after_ids.size() > 0:
		var arr: Array = []
		arr.resize(after_ids.size())
		for i in range(after_ids.size()):
			arr[i] = int(after_ids[i])

		var ctx := GroupLayoutOrder.new()
		ctx.group_index = g
		ctx.order = arr
		ctx.animate_to_position = true
		battle_view.set_group_order(ctx)


func _on_faded(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var dead_id := int(d.get(Keys.TARGET_ID, 0))

	var v := battle_view.get_combatant(dead_id)
	if v != null:
		v.queue_free()
	battle_view.combatants_by_cid.erase(dead_id)


func _on_summon_windup(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}

	var g := int(d.get(Keys.GROUP_INDEX, e.event.group_index))
	var insert_index := int(d.get(Keys.INSERT_INDEX, -1))
	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	if summoned_id <= 0:
		return

	var before_order: PackedInt32Array = d.get(Keys.BEFORE_ORDER_IDS, PackedInt32Array())
	var layout_count := int(d.get(Keys.WINDUP_LAYOUT_COUNT, 0))
	if layout_count <= 0 and before_order != null and before_order.size() > 0:
		layout_count = before_order.size()
	if layout_count <= 0:
		layout_count = battle_view.get_combatant_views_for_group(g).size()

	var v := battle_view.get_combatant(summoned_id)
	if v == null:
		return

	v.is_alive = false

	var slot_global := battle_view.get_summon_slot_position_for_layout_count(g, insert_index, layout_count)
	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	v.position = group.to_local(slot_global)
	v.anchor_position = v.position
	v.has_anchor_position = true

	if v.character_art != null:
		var c := v.character_art.modulate
		c.a = 0.0
		v.character_art.modulate = c

	if v.tween_misc:
		v.tween_misc.kill()
	v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if v.character_art != null:
		v.tween_misc.tween_property(v.character_art, "modulate:a", 1.0, maxf(e.duration, 0.01))


func _on_summon_followthrough(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}

	var g := int(d.get(Keys.GROUP_INDEX, e.event.group_index))
	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	var after_ids: PackedInt32Array = d.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())

	var v := battle_view.get_combatant(summoned_id)
	if v != null:
		v.is_alive = true

	if after_ids.size() > 0:
		var arr: Array = []
		arr.resize(after_ids.size())
		for i in range(after_ids.size()):
			arr[i] = int(after_ids[i])

		var ctx := GroupLayoutOrder.new()
		ctx.group_index = g
		ctx.order = arr
		ctx.animate_to_position = true
		battle_view.set_group_order(ctx)


func _on_summoned(e: EventPackage) -> void:
	var cid := int(e.event.data.get(Keys.SUMMONED_ID, 0))
	var g := int(e.event.data.get(Keys.GROUP_INDEX, e.event.group_index))
	var idx := int(e.event.data.get(Keys.INSERT_INDEX, -1))
	if cid <= 0:
		return

	var v := battle_view.get_or_create_combatant_view(cid, g, idx, true)
	if v == null:
		return

	var spec: Dictionary = e.event.data.get(Keys.SUMMON_SPEC, {})
	v.apply_spawn_spec(spec)

	if v.character_art != null:
		v.character_art.modulate.a = 0.0
		if v.tween_misc:
			v.tween_misc.kill()
		v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		v.tween_misc.tween_property(v.character_art, "modulate:a", 1.0, maxf(e.duration, 0.01))


func _on_summon_reserve_released(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	var card_uid := String(d.get(Keys.CARD_UID, ""))
	if summoned_id <= 0 or card_uid == "":
		return
	Events.summon_reserve_card_released.emit(summoned_id, card_uid)


func _on_scope_begin(_e: EventPackage) -> void:
	pass

func _on_scope_end(_e: EventPackage) -> void:
	pass

func _on_attack_prep_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	var order := FocusOrder.new()
	order.duration = duration
	order.attacker_id = info.attacker_id
	order.target_ids = info.get_all_target_ids()
	order.dim_bg = 0.6
	order.dim_uninvolved = 0.55
	order.scale_involved = 1.08
	order.scale_uninvolved = 1.0
	order.drift_involved = 20.0

	battle_view.apply_focus(order)

func _on_strike_windup_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	var attacker := battle_view.get_combatant(info.attacker_id)
	if attacker == null:
		return

	var o := StrikeWindupOrder.new()
	o.duration = duration
	o.attacker_id = info.attacker_id
	o.target_ids = info.get_all_target_ids()
	o.attack_mode = info.attack_mode
	o.projectile_scene_path = info.projectile_scene_path
	if o.projectile_scene_path == "" and int(o.attack_mode) == int(Attack.Mode.RANGED):
		o.projectile_scene_path = "res://VFX/projectiles/fireball/fireball.tscn"
	o.strike_count = info.strike_count
	o.total_hit_count = info.total_hit_count
	o.attack_info = info

	attacker.play_strike_windup(o, battle_view)

func _on_strike_followthrough_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	var attacker := battle_view.get_combatant(info.attacker_id)
	if attacker == null:
		return

	var o := StrikeFollowthroughOrder.new()
	o.duration = duration
	o.attacker_id = info.attacker_id
	o.target_ids = info.get_all_target_ids()
	o.attack_mode = info.attack_mode
	o.strike_count = info.strike_count
	o.total_hit_count = info.total_hit_count
	o.has_lethal_hit = info.has_lethal_hit
	o.attack_info = info

	# one attacker pose for the whole followthrough window
	attacker.play_strike_followthrough(o, battle_view)

	# individual strike consequences happen over time inside the phase
	_play_attack_followthrough_async(info, duration)

func _play_attack_followthrough_async(info: AttackPresentationInfo, duration: float) -> void:
	if info == null or duration <= 0.0:
		return

	_play_attack_followthrough_steps_async(info, duration)


func _play_attack_followthrough_steps_async(info: AttackPresentationInfo, duration: float) -> void:
	var start_msec := Time.get_ticks_msec()

	for s in info.strikes:
		if s == null:
			continue

		var elapsed := float(Time.get_ticks_msec() - start_msec) / 1000.0
		var strike_t := clampf(float(s.t0_ratio) * duration, 0.0, duration)
		var wait_t := strike_t - elapsed
		if wait_t > 0.0:
			await battle_view.get_tree().create_timer(wait_t).timeout

		_apply_single_strike_followthrough(info, s, duration)

func _apply_single_strike_followthrough(info: AttackPresentationInfo, s: StrikePresentationInfo, duration: float) -> void:
	if info == null or s == null:
		return

	# Ranged strike: impact its matching projectile at this strike's time.
	if int(info.attack_mode) == int(Attack.Mode.RANGED):
		var attacker := battle_view.get_combatant(info.attacker_id)
		if attacker != null:
			attacker.play_projectile_impact_for_strike(info.attacker_id, s.strike_index, battle_view)

	for h in s.hits:
		if h == null:
			continue

		var dmg := BattleEvent.new(BattleEvent.Type.DAMAGE_APPLIED)
		dmg.data = {
			Keys.TARGET_ID: h.target_id,
			Keys.FINAL_AMOUNT: h.amount,
			Keys.AFTER_HEALTH: h.after_health,
			Keys.WAS_LETHAL: h.was_lethal,
			Keys.BEFORE_HEALTH: h.before_health,
		}
		_on_damage_applied(_make_epkg_from_event(dmg, duration))

		for se in h.status_events:
			if se != null:
				_on_status_changed(_make_epkg_from_event(se, duration))

		if h.was_lethal:
			if h.died_event != null:
				_on_death_windup(_make_epkg_from_event(h.died_event, duration))
				_on_death_followthrough(_make_epkg_from_event(h.died_event, duration))
				_on_died(_make_epkg_from_event(h.died_event, duration))
			elif h.faded_event != null:
				_on_fade_windup(_make_epkg_from_event(h.faded_event, duration))
				_on_fade_followthrough(_make_epkg_from_event(h.faded_event, duration))
				_on_faded(_make_epkg_from_event(h.faded_event, duration))

func _on_attack_wrapup_from_info(info: AttackPresentationInfo, duration: float) -> void:
	if info == null:
		return

	battle_view.clear_focus(duration)

	var attacker := battle_view.get_combatant(info.attacker_id)
	if attacker != null:
		attacker.clear_strike_pose(duration)

	if int(info.attack_mode) == int(Attack.Mode.RANGED):
		for i in range(info.strikes.size()):
			var key := int(battle_view.make_projectile_key(info.attacker_id, i))
			var projectile := battle_view.take_projectile(key)
			if projectile != null and is_instance_valid(projectile):
				projectile.queue_free()
