# sigil_of_mana.gd

class_name SigilOfManaArcanum extends Arcanum

const ID := &"sigil_of_mana"

var member_var := 0

func get_id() -> StringName:
	return ID

func get_timed_proc_flags() -> int:
	return TimedProc.BATTLE_START

func on_battle_start(ctx: SimArcanumContext) -> void:
	var api: SimBattleAPI = ctx.api if ctx != null else null
	if api == null:
		return

	var player_id := int(api.get_player_id())
	if player_id <= 0:
		return

	var mana_ctx := ManaContext.new()
	mana_ctx.source_id = player_id
	mana_ctx.mode = ManaContext.Mode.GAIN_MANA
	mana_ctx.amount = 1
	mana_ctx.reason = "arcanum_battle_start"
	api.gain_mana(mana_ctx)

func _add_mana(_arcanum_display: ArcanumDisplay) -> void:
	#arcanum_display.flash()
	#var player := arcanum_display.get_tree().get_first_node_in_group("player") as Player
	#if player:
		#player.combatant_data.add_mana(1)
	pass
