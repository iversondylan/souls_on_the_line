class_name AmplifyStatus extends Status

const AMPLIFY_ID := "amplify"
const MULT_VALUE := 0.5

func init_status(target: Node) -> void:
	assert(target.get("modifier_system"), "No modifier on %s" % target)
	var dmg_dealt_modifier: Modifier = (target as Fighter).modifier_system.get_modifier(Modifier.Type.DMG_DEALT)
	assert(dmg_dealt_modifier, "No dmg dealt modifier on %s" % target)
	var amplify_modifier_value := dmg_dealt_modifier.get_value(AMPLIFY_ID)
	
	if !amplify_modifier_value:
		amplify_modifier_value = ModifierValue.create_new_modifier(AMPLIFY_ID, ModifierValue.Type.MULT)
		amplify_modifier_value.mult_value = MULT_VALUE
		dmg_dealt_modifier.add_new_value(amplify_modifier_value)
	if !status_changed.is_connected(_on_status_changed):
		status_changed.connect(_on_status_changed.bind(dmg_dealt_modifier))

func get_modifier_tokens() -> Array[ModifierToken]:
	# If expired, contribute nothing
	if duration <= 0:
		return []
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = AMPLIFY_ID
	token.owner = status_parent
	token.scope = ModifierToken.Scope.SELF
	token.priority = 0
	token.tags = [AMPLIFY_ID]
	
	return [token]

##Must return true if this status contributes a numerical modifier.
func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func _on_status_changed(dmg_dealt_modifier: Modifier) -> void:
	if duration <= 0 and dmg_dealt_modifier:
		dmg_dealt_modifier.remove_value(AMPLIFY_ID)

func get_tooltip() -> String:
	if duration == 1:
		var base_tooltip: String = "Amplify: deals %s%% more damage for 1 turn."
		return base_tooltip % floori(MULT_VALUE*100)
	var base_tooltip: String = "Amplify: deals %s%% more damage for %s turns."
	return base_tooltip % [floori(MULT_VALUE*100), duration]
