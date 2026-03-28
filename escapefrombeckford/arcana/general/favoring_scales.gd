# favoring_scales.gd

class_name FavoringScales extends Arcanum

const ID := "favoring_scales"

@export_range(1, 100) var discount := 50

func get_id() -> StringName:
	return ID

func on_shop_context_started(ctx: ShopContext) -> void:
	if ctx == null:
		return
	ctx.apply_all_discount_percent(discount)
