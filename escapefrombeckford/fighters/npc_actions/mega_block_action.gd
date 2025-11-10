extends NPCAction

@export var n_armor: int = 15
@export var hp_threshold: int = 5
var already_used: bool = false

func is_performable() -> bool:
	if !combatant or already_used:
		return false
	var is_low: bool = combatant.combatant_data.health <= hp_threshold
	already_used = is_low
	return is_low

func perform_action() -> void:
	if !combatant or !target:
		return
	
	var block_effect:= BlockEffect.new()
	block_effect.n_armor = n_armor
	block_effect.sound = sound
	block_effect.execute([combatant])
	
	get_tree().create_timer(0.6, false).timeout.connect(
		func():
			#combatant.doing_turn = false
			#combatant.turn_complete = true
			action_performed.emit(self)
			combatant.turn_complete()
	)

func update_action_intent() -> void:
	intent_data.base_text = str(n_armor)
