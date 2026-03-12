# battle_event_director.gd

class_name BattleEventDirector extends RefCounted

var battle_view: BattleView


@export var spawn_pause_sec: float = 0.04
@export var summon_pause_sec: float = 0.06
@export var hit_pause_sec: float = 0.05

func bind(new_battle_view: BattleView) -> void:
	battle_view = new_battle_view

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
		BattleEvent.Type.ATTACK_PREP:
			_on_attack_prep(e)
		BattleEvent.Type.ATTACK_WRAPUP:
			_on_attack_wrapup(e)
		BattleEvent.Type.STRIKE_WINDUP:
			_on_strike_windup(e)
		BattleEvent.Type.STRIKE_FOLLOWTHROUGH:
			_on_strike_followthrough(e)
		BattleEvent.Type.DAMAGE_APPLIED:
			_on_damage_applied(e)
		BattleEvent.Type.STATUS_APPLIED:
			_on_status_applied(e)
		BattleEvent.Type.STATUS_REMOVED:
			_on_status_removed(e)
		BattleEvent.Type.STATUS_CHANGED:
			_on_status_changed(e)
		BattleEvent.Type.DEATH_WINDUP:
			_on_death_windup(e)
		BattleEvent.Type.DEATH_FOLLOWTHROUGH:
			_on_death_followthrough(e)
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
		BattleEvent.Type.DISCARD_RESOLVED:
			pass
		BattleEvent.Type.FADE_WINDUP:
			_on_fade_windup(e)
		BattleEvent.Type.FADE_FOLLOWTHROUGH:
			_on_fade_followthrough(e)
		BattleEvent.Type.FADED:
			_on_faded(e)
		BattleEvent.Type.SUMMON_WINDUP:
			_on_summon_windup(e)
		BattleEvent.Type.SUMMONED:
			_on_summoned(e)
		BattleEvent.Type.SUMMON_FOLLOWTHROUGH:
			_on_summon_followthrough(e)
		BattleEvent.Type.SUMMON_RESERVE_RELEASED:
			_on_summon_reserve_released(e)
		_:
			pass

func _on_spawned(e: EventPackage) -> void:
	var cid := int(e.event.data.get(Keys.SPAWNED_ID, 0))
	var g := int(e.event.data.get(Keys.GROUP_INDEX, e.event.group_index))
	var idx := int(e.event.data.get(Keys.INSERT_INDEX, -1))
	var is_player := bool(e.event.data.get(Keys.IS_PLAYER, false))
	var after_ids : PackedInt32Array = e.event.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	#print("battle_event_director.gd _on_spawned() cid: %s, group: %s, ind: %s" % [cid, g, idx])
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

	# Fast membership set
	var pending_set := {}
	for cid in pending_ids:
		pending_set[int(cid)] = true

	for v: CombatantView in battle_view.get_all_combatant_views():
		if v == null or !is_instance_valid(v):
			continue
		if !v.is_alive:
			v.set_pending_turn_glow(CombatantView.TurnStatus.NONE) # or CombatantView enum if you moved it
			continue

		if int(v.cid) == active_id:
			v.set_pending_turn_glow(CombatantView.TurnStatus.TURN_ACTIVE)
		elif pending_set.has(int(v.cid)):
			v.set_pending_turn_glow(CombatantView.TurnStatus.TURN_PENDING)
		else:
			v.set_pending_turn_glow(CombatantView.TurnStatus.NONE)

func _on_formation_set(e: EventPackage) -> void:
	# Your payload: {player_id, group_0, group_1}
	var g0: Array = e.event.data.get(Keys.GROUP_0, [])
	var g1: Array = e.event.data.get(Keys.GROUP_1, [])
	#print("battle_event_director.gd _on_formation_set() g0: %s, g1: %s" % [g0, g1])
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
	
	# tune these later
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
	# Current moved event stores before/after orders.
	var after_ids : PackedInt32Array = e.event.data.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())
	var g := int(e.event.group_index)
	#print("battle_event_director.gd _on_moved() after_ids: %s, g: %s" % [after_ids, g])
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
	#print("battle_event_director.gd _on_targeted() src: %s, targets: %s" % [src, targets])
	if combatant != null:
		combatant.play_targeting()
	
	for tid in targets:
		var tv := battle_view.get_combatant(int(tid))
		if tv != null:
			tv.show_targeted(true)

func _on_damage_applied(e: EventPackage) -> void:
	var src := int(e.event.data.get(Keys.SOURCE_ID, 0))
	var tid := int(e.event.data.get(Keys.TARGET_ID, 0))
	var amount := int(e.event.data.get(Keys.FINAL_AMOUNT, 0))
	var lethal := bool(e.event.data.get(Keys.WAS_LETHAL, false))
	var target_combatant := battle_view.get_combatant(tid)
	var after_health := int(e.event.data.get(Keys.AFTER_HEALTH, 1))
	#print("battle_event_director.gd _on_damage_applied() src: %s, tid: %s, amount: %s" % [src, tid, amount])
	if target_combatant != null:
		target_combatant.play_hit()
		target_combatant.set_health(after_health, lethal)
		target_combatant.pop_damage_number(amount)

func _on_status_applied(e: EventPackage) -> void:
	#print("battle_event_director.gd _on_status_applied()")
	var o := StatusAppliedOrder.new()
	o.duration = e.duration
	o.source_id = int(e.event.data.get(Keys.SOURCE_ID, 0))
	o.target_id = int(e.event.data.get(Keys.TARGET_ID, 0))
	o.status_id = e.event.data.get(Keys.STATUS_ID, &"")
	o.intensity = int(e.event.data.get(Keys.INTENSITY, 1))
	o.turns_duration = int(e.event.data.get(Keys.DURATION, 0))

	var target := battle_view.get_combatant(o.target_id)
	if target != null and target.status_view_grid:
		target.status_view_grid.apply_status(o)

func _on_status_removed(e: EventPackage) -> void:
	var o := StatusRemovedOrder.new()
	o.duration = e.duration
	o.source_id = int(e.event.data.get(Keys.SOURCE_ID, 0))
	o.target_id = int(e.event.data.get(Keys.TARGET_ID, 0))
	o.status_id = e.event.data.get(Keys.STATUS_ID, &"")
	o.intensity = int(e.event.data.get(Keys.INTENSITY, 1))
	
	var target := battle_view.get_combatant(o.target_id)
	if target != null and target.status_view_grid:
		target.status_view_grid.remove_status(o)

func _on_status_changed(e: EventPackage) -> void:
	var o := StatusAppliedOrder.new()
	o.duration = e.duration
	o.source_id = int(e.event.data.get(Keys.SOURCE_ID, 0))
	o.target_id = int(e.event.data.get(Keys.TARGET_ID, 0))
	o.status_id = e.event.data.get(Keys.STATUS_ID, &"")
	o.intensity = int(e.event.data.get(Keys.INTENSITY, 1))
	o.turns_duration = int(e.event.data.get(Keys.DURATION, 0))
	
	var target := battle_view.get_combatant(o.target_id)
	if target != null and target.status_view_grid:
		# you probably want a dedicated method, but this works if apply_status updates if present
		target.status_view_grid.apply_status(o)

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
	
	# You decide where the UI actually lives. This is the cleanest:
	if cv.intent_container != null:
		cv.intent_container.apply_intent(planned_idx, icon_uid, icon_ranged_uid, is_ranged, intent_text, tooltip_text)

func _on_died(e: EventPackage) -> void:
	var dead_id := int(e.event.data.get(Keys.TARGET_ID, 0))
	if dead_id <= 0:
		return
	
	var v := battle_view.get_combatant(dead_id)
	if v != null:
		v.queue_free()
	
	# Remove from BattleView mapping so future lookups fail safely
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
	
	# 1) Remove from the visual group registry so layout ignores it
	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)
	
	# 2) Optionally hide or keep visible-but-dark off to the side
	var dead_view := battle_view.get_combatant(dead_id)
	if dead_view != null:
		dead_view.on_death_followthrough(e.duration)
	
	# 3) Re-layout to after_order_ids
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

# battle_event_director.gd (add)
func _on_discard_requested(e: EventPackage) -> void:
	if e == null:
		return
	var d : Dictionary = e.event.data if e.event.data != null else {}
	
	var ctx := DiscardContext.new()
	ctx.source_id = int(d.get(Keys.SOURCE_ID, 0))
	ctx.amount = int(d.get(Keys.AMOUNT, 0))
	ctx.card_uid = String(d.get(Keys.CARD_UID, ""))

	# Completion callback routes back to SIM.
	# NOTE: this stays VIEW-side; it just calls SIM API when user finishes.
	var sim_host : SimHost = battle_view.sim_host if battle_view != null else null
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

	# Just fade art out; do NOT unregister/re-layout here
	if v.tween_misc:
		v.tween_misc.kill()
	v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	v.tween_misc.tween_property(v.character_art, "modulate:a", 0.0, maxf(e.duration, 0.01))


func _on_fade_followthrough(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var dead_id := int(d.get(Keys.TARGET_ID, 0))
	var g := int(d.get(Keys.GROUP_INDEX, e.event.group_index))
	var after_ids: PackedInt32Array = d.get(Keys.AFTER_ORDER_IDS, PackedInt32Array())

	# Now remove from layout + re-layout the survivors
	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	if group != null:
		group.unregister_cid(dead_id)

	var dv := battle_view.get_combatant(dead_id)
	if dv != null:
		dv.is_alive = false # ensures GroupView ignores it going forward

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

	# Queue free old combatant here (semantic end)
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

	# Determine layout_count from snapshot (critical for summon-replace)
	var before_order: PackedInt32Array = d.get(Keys.BEFORE_ORDER_IDS, PackedInt32Array())
	var layout_count := int(d.get(Keys.WINDUP_LAYOUT_COUNT, 0))
	if layout_count <= 0 and before_order != null and before_order.size() > 0:
		layout_count = before_order.size()
	if layout_count <= 0:
		layout_count = battle_view.get_combatant_views_for_group(g).size()

	# Summoned view should already exist by now because SUMMONED event creates it.
	# But guard anyway.
	var v := battle_view.get_combatant(summoned_id)
	if v == null:
		return

	# Exclude from layout during windup so it doesn't push units outward
	v.is_alive = false

	# Place at "ghost slot" using layout_count from BEFORE snapshot
	var slot_global := battle_view.get_summon_slot_position_for_layout_count(g, insert_index, layout_count)

	var group: GroupView = battle_view.friendly_group if g == 0 else battle_view.enemy_group
	v.position = group.to_local(slot_global)
	v.anchor_position = v.position
	v.has_anchor_position = true

	# Fade in during windup
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

	# Now the unit participates in layout and moves into its final spot
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
	# Spawn-only: create the view, apply spec, BUT do not do the fancy fade/move here.
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

	# Let windup handler decide where it appears + alpha.
	# Safe default: keep it invisible until SUMMON_WINDUP arrives.
	if v.character_art != null:
		v.character_art.modulate.a = 0.0
		#v.character_art.modulate = c
		if v.tween_misc:
			v.tween_misc.kill()
		v.tween_misc = v.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		v.tween_misc.tween_property(v.character_art, "modulate:a", 1, maxf(e.duration, 0.01))

func _on_summon_reserve_released(e: EventPackage) -> void:
	var d := e.event.data if e.event.data != null else {}
	var summoned_id := int(d.get(Keys.SUMMONED_ID, 0))
	var card_uid := String(d.get(Keys.CARD_UID, ""))
	if summoned_id <= 0 or card_uid == "":
		return
	Events.summon_reserve_card_released.emit(summoned_id, card_uid)

func _on_scope_begin(_e: EventPackage) -> void:
	#print("battle_event_director.gd _on_scope_begin()")
	# Later: update “phase title”, camera focus, etc.
	pass

func _on_scope_end(_e: EventPackage) -> void:
	#print("battle_event_director.gd _on_scope_end()")
	pass

func play_beat(pkg: BeatPackage) -> void:
	if battle_view == null or pkg.beat.is_empty():
		return
	if !battle_view._playing or pkg.gen != battle_view._playback_gen:
		return

	# Optional: find marker for routing decisions
	#var marker := _find_marker(pkg.beat)

	for e in pkg.beat:
		# cancellation check
		if !battle_view._playing or pkg.gen != battle_view._playback_gen:
			return
		var epkg := EventPackage.new()
		epkg.event = e
		epkg.duration = pkg.duration
		on_event(epkg)
