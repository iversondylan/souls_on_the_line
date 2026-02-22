# turn_engine_host.gd
class_name TurnEngineHost extends RefCounted

# ------------------------------------------------------------
# Small helper: returns an awaitable Signal that fires next tick
# ------------------------------------------------------------
class _ImmediateAwaiter extends RefCounted:
	signal completed
	func _fire() -> void:
		completed.emit()

func _await_next_tick() -> Signal:
	var a := _ImmediateAwaiter.new()
	# Defer emit so `await` always has a chance to subscribe.
	a.call_deferred("_fire")
	return a.completed


# -------------------------
# Required query interface
# -------------------------
func get_group_order_ids(group_index: int) -> PackedInt32Array:
	return PackedInt32Array()

func get_group_index_of(combat_id: int) -> int:
	return -1

func is_alive(combat_id: int) -> bool:
	return false

func is_player(combat_id: int) -> bool:
	return false

func get_player_id() -> int:
	return 0


# -------------------------
# Player boundary hooks
# -------------------------
# Called when the engine is about to hand control to the player.
func begin_player_turn_async() -> Variant:
	# default: no-op but awaitable
	return true#_await_next_tick()

# Called after the player has finished and “end turn” resolutions are done.
func end_player_turn_async() -> Variant:
	# default: no-op but awaitable
	return true#_await_next_tick()
