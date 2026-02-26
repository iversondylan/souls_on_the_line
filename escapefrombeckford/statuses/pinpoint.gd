# pinpoint.gd

class_name PinpointStatus extends Status

const ID := &"pinpoint"
const MULT_VALUE := 0.5

func get_id() -> StringName:
	return ID

func get_modifier_tokens(ctx: StatusTokenContext) -> Array[ModifierToken]:
	print("pinpoint.gd get_modifier_tokens()")
	if !ctx:
		return []

	if expiration_policy == Status.ExpirationPolicy.DURATION and ctx.duration <= 0:
		return []

	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_TAKEN
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.scope = ModifierToken.Scope.SELF
	token.priority = 0
	token.tags = [ID]

	Status.set_token_owner(token, ctx)
	print("pinpoint.gd token.mult_value ", token.mult_value)
	return [token]

##Must return true if this status contributes a numerical modifier.
func contributes_modifier() -> bool:
	return true

##Must return type of numerical modifier.
func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_TAKEN]

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
