class_name StatusEffect
extends Effect

var status: Status
##auras need to have their battle_scene defined OR PERHAPS NOT
##var battle_scene: BattleScene
##for non-auras, targets should be aura targets,
##for auras, targets should be the aura source
func execute(targets: Array[Fighter]) -> void:
	#print("status_effect.gd execute()")
	#if status.aura_type == Status.AuraType.NONE:
	#print("status_effect.gd aura_type_none")
	for target in targets:
		if !target:
			continue
		if target is Fighter:
			target.combatant.status_grid.add_status(status)
	#else:
		#print("status_effect.gd aura_type_not_none")
		#Events.aura_changed.emit(targets[0], status)
	#SFXPlayer.play(sound)
