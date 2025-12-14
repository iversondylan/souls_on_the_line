class_name PinpointStatus extends Status

const ID := "pinpoint"
const MULT_VALUE := 0.5

#func init_status(_target: Node) -> void:
	#pass
	#assert(target.get("modifier_system"), "No modifier on %s" % target)
	#var dmg_taken_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_TAKEN)
	#assert(dmg_taken_modifier, "No dmg taken modifier on %s" % target)
	#var pinpoint_modifier_value := dmg_taken_modifier.get_value(ID)
	#
	#if !pinpoint_modifier_value:
		#pinpoint_modifier_value = ModifierValue.create_new_modifier(ID, ModifierValue.Type.MULT)
		#pinpoint_modifier_value.mult_value = MODIFIER
		#dmg_taken_modifier.add_new_value(pinpoint_modifier_value)
	#if !status_changed.is_connected(_on_status_changed):
		#status_changed.connect(_on_status_changed.bind(dmg_taken_modifier))

func get_modifier_tokens() -> Array[ModifierToken]:
	# If expired, contribute nothing
	#print("pinpoint.gd get_modifier_tokens()")
	if duration <= 0:
		return []
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_TAKEN
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.owner = status_parent
	token.scope = ModifierToken.Scope.SELF
	token.priority = 0
	token.tags = [ID]
	
	return [token]

##Must return true if this status contributes a numerical modifier.
func contributes_modifier() -> bool:
	return true

##Must return type of numerical modifier.
func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func _on_status_changed(dmg_taken_modifier: Modifier) -> void:
	if duration <= 0 and dmg_taken_modifier:
		dmg_taken_modifier.remove_value(ID)
	
func get_tooltip() -> String:
	if duration == 1:
		var base_tooltip: String = "Pinpoint: takes %s%% more damage for 1 turn."
		return base_tooltip % floori(MULT_VALUE*100)
	else:
		var base_tooltip: String = "Pinpoint: takes %s%% more damage for %s turns."
		return base_tooltip % [floori(MULT_VALUE*100), duration]
