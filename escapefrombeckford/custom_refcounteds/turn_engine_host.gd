class_name TurnEngineHost extends RefCounted

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


# ------------------------------------------------------------
# Internal: coroutine marker (no real delay)
# ------------------------------------------------------------
func _coroutine_marker() -> void:
	# This makes the function a coroutine in Godot 4.x without actually yielding.
	if false:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			await tree.process_frame


# -------------------------
# Player boundary hooks
# -------------------------
func begin_player_turn_async() -> void:
	# default: no-op but awaitable
	await _coroutine_marker()

func end_player_turn_async() -> void:
	# default: no-op but awaitable
	await _coroutine_marker()
