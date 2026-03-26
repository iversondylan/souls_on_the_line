# unruly_pyric_wraps.gd

extends Arcanum

const ID := &"unruly_pyric_wraps"

@export var damage: int = 2

func get_id() -> StringName:
	return ID


func activate_arcanum(ctx: ArcanumContext) -> Variant:
	#
	#if ctx == null or ctx.api == null:
		#return null
	#var is_sim : bool = (ctx.params != null and ctx.params.get(Keys.MODE, &"") == Keys.MODE_SIM)
	## -------------------------
	## LIVE PATH (scene tree)
	## -------------------------
	#if !is_sim and arcanum_display != null and is_instance_valid(arcanum_display):
		#var enemies: Array[Fighter] = []
		#for node: Node in arcanum_display.get_tree().get_nodes_in_group("enemies"):
			#if node is Fighter:
				#enemies.push_back(node)
			#else:
				#push_warning("unruly_pyric_wraps.gd error: node is not Fighter")
#
		#var damage_effect := DamageEffect.new()
		#damage_effect.targets = enemies
		#damage_effect.n_damage = damage
		#damage_effect.modifier_type = Modifier.Type.NO_MODIFIER
		#damage_effect.execute(ctx.api)
#
		#arcanum_display.flash()
		#return null

	# -------------------------
	# HEADLESS PATH (sim)
	# -------------------------
	var source_id := _get_source_id(ctx)
	var enemy_ids: Array[int] = []
	if ctx.api.has_method("get_enemies_of") and source_id > 0:
		enemy_ids = ctx.api.call("get_enemies_of", source_id)
	elif ctx.api.has_method("get_combatants_in_group"):
		# fallback: ENEMY group index = 1
		enemy_ids = ctx.api.call("get_combatants_in_group", 1, false)
	else:
		push_warning("unruly_pyric_wraps.gd headless: api missing enemy query helpers")
		return null
	for tid in enemy_ids:
		_apply_damage_headless(ctx.api, source_id, int(tid), damage)

	return null


func _get_source_id(ctx: ArcanumContext) -> int:
	#if ctx.player != null and is_instance_valid(ctx.player):
		#if ctx.player.combatant_data != null:
			#return int(ctx.player.combatant_data.combat_id)
	return ctx.api.get_player_id()
	#if ctx.params != null:
		#if ctx.params.has(Keys.SOURCE_ID):
			#return int(ctx.params[Keys.SOURCE_ID])
		#if ctx.params.has("source_id"):
			#return int(ctx.params["source_id"])

	#return 0


func _apply_damage_headless(api: SimBattleAPI, source_id: int, target_id: int, amount: int) -> void:
	if api == null or target_id <= 0:
		return
	var d := DamageContext.new()

	_safe_set(d, &"source_id", source_id)
	_safe_set(d, &"target_id", target_id)
	_safe_set(d, &"origin_arcanum_id", get_id())
	_safe_set(d, &"reason", "arcanum_proc")

	# IMPORTANT: your sim DamageResolver reads ctx.base_amount.
	_safe_set_any(d, [&"base_amount"], amount)

	_safe_set_any(d, [&"deal_modifier_type"], int(Modifier.Type.NO_MODIFIER))
	_safe_set_any(d, [&"take_modifier_type"], int(Modifier.Type.NO_MODIFIER))

	if api.has_method("resolve_damage"):
		api.call("resolve_damage", d)
	elif api.has_method("resolve_damage_immediate"):
		api.call("resolve_damage_immediate", d)
	else:
		push_warning("unruly_pyric_wraps.gd headless: api missing resolve_damage")


func _safe_set(obj: Object, prop: StringName, val) -> bool:
	if obj == null:
		return false
	for p in obj.get_property_list():
		if p.name == prop:
			obj.set(prop, val)
			return true
	return false


func _safe_set_any(obj: Object, props: Array[StringName], val) -> bool:
	for prop in props:
		if _safe_set(obj, prop, val):
			return true
	return false

func get_beats() -> int:
	return Beats.IN_OUT
