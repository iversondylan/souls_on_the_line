# npc_summon_sequence.gd
class_name NPCSummonSequence
extends NPCEffectSequence

const MAX_UNITS_PER_GROUP := 7

func execute(ctx: NPCAIContext, on_done: Callable) -> void:
	# Defensive: always finish
	if !ctx:
		on_done.call()
		return

	var fighter: Fighter = ctx.combatant
	var battle_scene: BattleScene = ctx.battle_scene
	if !fighter or !battle_scene:
		on_done.call()
		return

	# Strictly stateless: no side effects during forecast
	if bool(ctx.forecast):
		on_done.call()
		return

	var params: Dictionary = ctx.params if ctx.params else {}

	# Robust defaults:
	# - group_index default 0 (friendly)
	# - insert_index default 0 (front)
	# - count default 1
	var group_index := int(params.get(NPCKeys.GROUP_INDEX, 0))
	var insert_index := int(params.get(NPCKeys.INSERT_INDEX, 0))
	var count := int(params.get(NPCKeys.SUMMON_COUNT, 1))

	# Clamp group index to known groups (0/1).
	group_index = clampi(group_index, 0, 1)

	if count <= 0:
		on_done.call()
		return

	# Resolve summon data (CombatantData resource OR a path string OR null for SummonEffect fallback)
	var summon_data_orig: CombatantData = _resolve_summon_data(params.get(NPCKeys.SUMMON_DATA, SummonEffect.DEFAULT_SUMMON_DATA))
	var summon_data: CombatantData = summon_data_orig.duplicate()
	# Optional sound override (Sound/AudioStream-like resource), SummonEffect will fallback if null
	var summon_sound = params.get(NPCKeys.SUMMON_SOUND, null)

	# ------------------------------------------------------------
	# Capacity enforcement (NO fading; cancel whole effect if max)
	# ------------------------------------------------------------
	var n_existing := int(battle_scene.get_n_combatants_in_group(group_index))
	if n_existing >= MAX_UNITS_PER_GROUP:
		on_done.call()
		return
	if n_existing + count > MAX_UNITS_PER_GROUP:
		# Strict: no partial summon; cancel the effect
		on_done.call()
		return

	# ------------------------------------------------------------
	# Summon N units
	# ------------------------------------------------------------
	for i in range(count):
		# Re-check current size each iteration so insert clamping is correct
		var cur_n := int(battle_scene.get_n_combatants_in_group(group_index))

		# Clamp insert each time: allow insertion at end (=cur_n)
		var idx := clampi(insert_index, 0, cur_n)

		var effect := SummonEffect.new()
		effect.battle_scene = battle_scene
		effect.group_index = group_index
		effect.insert_index = idx

		if summon_data:
			effect.summon_data = summon_data

		if summon_sound:
			effect.sound = summon_sound

		effect.execute(ctx.battle_scene.api)

	on_done.call()


# -------------------------------------------------------------------
# Helpers (pure / stateless)
# -------------------------------------------------------------------

func _resolve_summon_data(value) -> CombatantData:
	# Accept:
	# - CombatantData resource
	# - String path to a CombatantData .tres
	# - null (use SummonEffect fallback)
	if value == null:
		return null

	if value is CombatantData:
		return value

	if value is String:
		var path := str(value)
		if path.is_empty():
			return null
		var res := load(path)
		if res is CombatantData:
			return res
		return null

	return null
