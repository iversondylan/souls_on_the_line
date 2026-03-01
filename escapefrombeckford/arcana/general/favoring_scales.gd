# favoring_scales.gd

class_name FavoringScales extends Arcanum

const ID := "favoring_scales"

@export_range(1, 100) var discount := 50

func get_id() -> StringName:
	return ID

func get_modifier_tokens_for(_target: Node) -> Array[ModifierToken]:
	var token := ModifierToken.new()
	token.type = Modifier.Type.SHOP_COST
	token.mult_value = -discount / 100.0
	token.scope = ModifierToken.ModScope.GLOBAL
	token.source_id = get_id()
	token.owner = arcanum_display
	return [token]

func contributes_modifier() -> bool:
	return true

func get_contributed_modifier_types() -> Array[Modifier.Type]:
	return [Modifier.Type.SHOP_COST]
