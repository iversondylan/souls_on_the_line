class_name PlayerRunState extends Resource

@export var current_health: int = 0
@export var max_health: int = 0

func initialize_from_player_data(player_data: PlayerData) -> void:
	if player_data == null:
		current_health = 0
		max_health = 0
		return
	max_health = maxi(int(player_data.max_health), 0)
	current_health = max_health

func clamp_health() -> void:
	current_health = clampi(int(current_health), 0, maxi(int(max_health), 0))

func set_max_health(new_max_health: int, keep_ratio: bool = false) -> void:
	var clamped_max := maxi(int(new_max_health), 0)
	if keep_ratio and max_health > 0:
		var ratio := float(current_health) / float(max_health)
		max_health = clamped_max
		current_health = clampi(roundi(float(max_health) * ratio), 0, max_health)
		return
	max_health = clamped_max
	clamp_health()

func change_max_health(amount: int, heal_added_health: bool = true) -> void:
	var previous_max := maxi(int(max_health), 0)
	set_max_health(previous_max + int(amount))
	if heal_added_health and amount > 0:
		current_health = clampi(int(current_health) + int(amount), 0, int(max_health))

func heal(ctx: HealContext) -> int:
	if ctx == null:
		return 0
	if ctx.flat_amount < 0 or ctx.of_total < 0.0 or ctx.of_missing < 0.0:
		push_warning("PlayerRunState.heal(): negative heal")
		return 0

	var clamped_max := maxi(int(max_health), 0)
	var initial_health := clampi(int(current_health), 0, clamped_max)
	var new_health := clampi(initial_health + int(ctx.flat_amount), 0, clamped_max)
	new_health = clampi(new_health + floori(float(clamped_max) * float(ctx.of_total)), 0, clamped_max)
	new_health = clampi(new_health + floori(float(clamped_max - new_health) * float(ctx.of_missing)), 0, clamped_max)
	current_health = new_health
	return int(current_health - initial_health)
