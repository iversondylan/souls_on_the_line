class_name StatusEffect
extends Effect

var status: Status
#auras need to have their battle_scene defined
var battle_scene: BattleScene
#for non-auras, targets should be aura targets,
#for auras, targets should be the aura source
func execute(targets: Array[Fighter]) -> void:
	match status.aura_type:
		Status.AuraType.NONE:
			for target in targets:
				#print("status_effect.gd execute(): there's a target: %s" % target)
				if !target:
					continue
				if target is Fighter:
					target.combatant.status_grid.add_status(status)
		Status.AuraType.ALLIES:
			pass
		Status.AuraType.ENEMIES:
			pass
	SFXPlayer.play(sound)
