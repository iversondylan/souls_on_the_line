# amplify.gd

class_name AmplifyStatus extends Status

const ID := &"amplify"
const MULT_VALUE := 0.5

func get_id() -> StringName:
	return ID

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	#print("amplify.gd get_modifier_tokens()")
	if !ctx:
		return []
	
	# Sim + live safe: use ctx.duration rather than resource duration
	if expiration_policy == Status.ExpirationPolicy.DURATION and ctx.duration <= 0:
		return []
	
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.ModScope.SELF
	token.priority = 0
	token.tags = [ID]
	
	Status.set_token_owner(token, ctx)
	#print("token.mult_value = ", token.mult_value)
	return [token]

##Must return true if this status contributes a numerical modifier.
func contributes_modifier() -> bool:
	return true

##Must return type of numerical modifier.
func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

#func _on_status_changed(dmg_dealt_modifier: Modifier) -> void:
	#if duration <= 0 and dmg_dealt_modifier:
		#dmg_dealt_modifier.remove_value(ID)
#
func get_tooltip(_intensity: int = 0, duration: int = 0) -> String:
	if duration == 1:
		return "Amplify: deals %s%% more damage for 1 turn." % floori(MULT_VALUE * 100)
	return "Amplify: deals %s%% more damage for %s turns." % [floori(MULT_VALUE * 100), duration]
