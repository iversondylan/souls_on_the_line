class_name Enemy extends NPCFighter

#func _on_target_area_area_entered(area: Area2D) -> void:
	#if area is CardTargetSelectorArea:
		#if area.card_target_selector.current_card.card_data.target_type == CardData.TargetType.SINGLE_ENEMY:
			#targeted_arrow.show()
	#pass

#func _on_target_area_area_exited(area: Area2D) -> void:
	#Events.combatant_untouched.emit(self)
	#if area is CardTargetSelectorArea:
	#targeted_arrow.hide()
	#pass
