class_name PinpointStatus extends Status

const STATUS_ID := "pinpoint"
const MODIFIER := 0.5

func init_status(target: Node) -> void:
	status_changed.connect(_on_status_changed.bind(target))
	print("cruelty_echoes.gd init_status() target: %s" % target)
	_on_status_changed(target)

func apply_status(_target: Node) -> void:
	status_applied.emit(self)
	print("%s should take %s%% more damage." % [_target, MODIFIER*100])
	
	#var damage_effect := DamageEffect.new()
	#damage_effect.n_damage = 12
	#damage_effect.execute([_target])
	#
	#status_applied.emit(self)

func _on_status_changed(target: Node) -> void:
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	var dmg_taken_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_TAKEN)
	assert(dmg_taken_modifier, "No dmg taken modifier on %s" % target)
	var pinpoint_modifier_value := dmg_taken_modifier.get_value(STATUS_ID)
	
	if !pinpoint_modifier_value:
		pinpoint_modifier_value = ModifierValue.create_new_modifier(STATUS_ID, ModifierValue.Type.MULT)
	
	pinpoint_modifier_value.mult_value = MODIFIER
	dmg_taken_modifier.add_new_value(pinpoint_modifier_value)
