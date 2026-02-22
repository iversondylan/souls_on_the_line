# vennards_vauxite.gd

extends Arcanum

const ID := &"vennards_vauxite.gd"

var block := 3

func activate_arcanum(ctx: ArcanumContext) -> Variant:
	var player := ctx.arcanum_display.get_tree().get_first_node_in_group("player") as Player
	var block_effect := BlockEffect.new()
	block_effect.targets = [player]
	block_effect.n_armor = block
	block_effect.execute(ctx.api)
	
	arcanum_display.flash()
	return null

func get_id() -> StringName:
	return ID
