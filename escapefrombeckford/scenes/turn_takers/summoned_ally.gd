class_name SummonedAlly extends NPCFighter

var card_data: CardData

func _ready() -> void:
	combatant.target_area_area_entered.connect(_on_target_area_area_entered)
	combatant.target_area_area_exited.connect(_on_target_area_area_exited)
	area_left.monitorable = true
	area_left.monitoring = true
	area_left.fighter = self
	target_area.combatant = self

func die():
	combatant_data.is_alive = false
	#if card_with_id:
	Events.summon_reserve_card_released.emit(self)
	var death_tween: Tween = create_tween()
	death_tween.tween_property(character_sprite, "modulate", Color.BLACK, 0.3)
	death_tween.finished.connect(
		func():
			battle_group.combatant_died(self)
				)

func bind_card(_card_data: CardData) -> void:
	card_data = _card_data

func spawned():
	reset()

func traverse_player() -> void:
	battle_group.ally_traverse_player(self)

#func _on_area_left_mouse_entered() -> void:
	#if combatant_data.team == 0 || combatant_data.team == 1:
		#Events.mouse_entered_ally_left.emit(self)
#
#func _on_area_left_mouse_exited() -> void:
	#if combatant_data.team == 0 || combatant_data.team == 1:
		#Events.mouse_exited_ally_left.emit(self)
