extends Arcanum

var block := 3

func activate_arcanum(arcanum_display: ArcanumDisplay) -> void:
	var player := arcanum_display.get_tree().get_first_node_in_group("player") as Player
	var block_effect := BlockEffect.new()
	block_effect.n_armor = block
	block_effect.execute([player])
	
	arcanum_display.flash()
