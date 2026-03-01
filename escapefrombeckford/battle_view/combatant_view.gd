# combatant_view.gd
class_name CombatantView
extends Node2D

var cid: int = 0

func apply_spawn_spec(spec: Dictionary) -> void:
	# You can pluck name, max_health, sprite paths, etc.
	# Keep safe: spec might be empty.
	var nm := String(spec.get(&"combatant_name", spec.get(&"name", "")))
	if nm != "":
		_set_name_label(nm)

	# If you include hp in spec, set UI immediately here.
	# Otherwise, you can wait for first HP update event.

func play_summon_fx() -> void:
	# TODO: puff + pop-in
	pass

func play_targeting() -> void:
	# TODO: subtle pulse/aim animation
	pass

func show_targeted(_is_targeted: bool) -> void:
	# TODO: toggle targeted arrow
	pass

func play_hit() -> void:
	# TODO: flash + shake
	pass

func pop_damage_number(_amount: int) -> void:
	# TODO: floating text
	pass

func play_attack_react() -> void:
	# optional: attacker recoil anim
	pass

func add_status_icon(_status_id: StringName) -> void:
	# TODO: update grid
	pass

func remove_status_icon(_status_id: StringName) -> void:
	# TODO: update grid
	pass

func _set_name_label(_nm: String) -> void:
	# Wire to your Label if you have it; safe no-op otherwise.
	pass
