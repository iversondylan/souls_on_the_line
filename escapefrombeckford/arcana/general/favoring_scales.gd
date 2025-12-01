class_name FavoringScales extends Arcanum

@export_range(1, 100) var discount := 50

func initialize_arcanum(arcanum_display: ArcanumDisplay) -> void:
	Events.request_shop_modifiers.connect(add_shop_modifier.bind(arcanum_display))
	Events.shop_modifier_acquired.emit()

func deactivate_relic(_arcanum_display: ArcanumDisplay) -> void:
	Events.shop_entered.disconnect(add_shop_modifier)

func add_shop_modifier(shop: Shop, arcanum_display: ArcanumDisplay) -> void:
	arcanum_display.flash()
	
	var shop_cost_modifier := shop.modifier_system.get_modifier(Modifier.Type.SHOP_COST)
	assert(shop_cost_modifier, "No shop cost modifier in shop.")
	
	var favoring_scales_value := shop_cost_modifier.get_value(id)
	
	if !favoring_scales_value:
		favoring_scales_value = ModifierValue.create_new_modifier(id, ModifierValue.Type.MULT)
		favoring_scales_value.mult_value = -1 * discount / 100.0
		shop_cost_modifier.add_new_value(favoring_scales_value)
		shop._update_items()
	
