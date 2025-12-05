class_name PinpointStatus extends Status

const ID := "focus"
const MODIFIER := 0.5

func init_status(target: Node) -> void:
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	var dmg_taken_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_TAKEN)
	assert(dmg_taken_modifier, "No dmg taken modifier on %s" % target)
	var pinpoint_modifier_value := dmg_taken_modifier.get_value(ID)
	
	if !pinpoint_modifier_value:
		pinpoint_modifier_value = ModifierValue.create_new_modifier(ID, ModifierValue.Type.MULT)
		pinpoint_modifier_value.mult_value = MODIFIER
		dmg_taken_modifier.add_new_value(pinpoint_modifier_value)
	if !status_changed.is_connected(_on_status_changed):
		status_changed.connect(_on_status_changed.bind(dmg_taken_modifier))
	#print("pinpoint.gd init_status() target: %s" % target)
	#_on_status_changed(target)
#
#func apply_status(_target: Node) -> void:
	#status_applied.emit(self)
	#print("%s should take %s%% more damage." % [_target, MODIFIER*100])

func _on_status_changed(dmg_taken_modifier: Modifier) -> void:
	if duration <= 0 and dmg_taken_modifier:
		dmg_taken_modifier.remove_value(ID)
	
func get_tooltip() -> String:
	if duration == 1:
		var base_tooltip: String = "Pinpoint: takes %s%% more damage for 1 turn."
		return base_tooltip % floori(MODIFIER*100)
	else:
		var base_tooltip: String = "Pinpoint: takes %s%% more damage for %s turns."
		return base_tooltip % [floori(MODIFIER*100), duration]
