# amplify.gd

class_name AmplifyStatus extends Status

const ID := "amplify"
const MULT_VALUE := 0.5

func get_id() -> String:
	return ID

func get_modifier_tokens() -> Array[ModifierToken]:
	# Live path uses this instance's runtime fields
	if duration <= 0:
		return []
	return [_make_token_node_owner(status_parent)]

func get_modifier_tokens_from_state(state: StatusState, owner_id: int) -> Array[ModifierToken]:
	# Sim path uses data-only state
	if !state or state.duration <= 0:
		return []
	return [_make_token_owner_id(owner_id)]

func _make_token_node_owner(owner: Fighter) -> ModifierToken:
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.owner = owner
	token.scope = ModifierToken.Scope.SELF
	token.priority = 0
	token.tags = [ID]
	return token

func _make_token_owner_id(owner_id: int) -> ModifierToken:
	var token := ModifierToken.new()
	token.type = Modifier.Type.DMG_DEALT
	token.mult_value = MULT_VALUE
	token.flat_value = 0
	token.source_id = ID
	token.owner_id = owner_id
	token.scope = ModifierToken.Scope.SELF
	token.priority = 0
	token.tags = [ID]
	return token


##Must return true if this status contributes a numerical modifier.
func contributes_modifier() -> bool:
	return true

##Must return type of numerical modifier.
func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.DMG_DEALT]

func _on_status_changed(dmg_dealt_modifier: Modifier) -> void:
	if duration <= 0 and dmg_dealt_modifier:
		dmg_dealt_modifier.remove_value(ID)

func get_tooltip() -> String:
	var base_tooltip: String
	if duration == 1:
		base_tooltip = "Amplify: deals %s%% more damage for 1 turn."
		return base_tooltip % floori(MULT_VALUE*100)
	base_tooltip = "Amplify: deals %s%% more damage for %s turns."
	return base_tooltip % [floori(MULT_VALUE*100), duration]
