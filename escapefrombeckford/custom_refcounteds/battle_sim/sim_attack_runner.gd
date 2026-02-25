# sim_attack_runner.gd

class_name SimAttackRunner extends RefCounted

static func run(api, spec: SimAttackSpec) -> bool:
	print("sim_attack_runner.gd run() attacker=%d alive=%s strikes=%d base=%d"
	% [spec.attacker_id, str(api.is_alive(spec.attacker_id)), spec.strikes, spec.base_damage])
	if api == null or spec == null:
		return false
	if spec.attacker_id <= 0 or !api.is_alive(spec.attacker_id):
		return false

	var strikes := maxi(int(spec.strikes), 1)
	var any := false

	for _s in range(strikes):
		if !api.is_alive(spec.attacker_id):
			break
		print("sim_attack_runner.gd run() strike=%d/%d using_explicit=%s"
		% [_s+1, strikes, str(!spec.explicit_target_ids.is_empty())])
		var target_ids: Array[int] = []
		if !spec.explicit_target_ids.is_empty():
			target_ids = spec.explicit_target_ids.duplicate()
		else:
			# You already have this; it’s the right place for Marked redirect, etc.
			target_ids = AttackTargeting.get_target_ids(api, spec.attacker_id, spec.params)

		# Alive filter
		target_ids = target_ids.filter(func(id): return int(id) > 0 and api.is_alive(int(id)))
		if target_ids.is_empty():
			continue

		for tid in target_ids:
			var d := DamageContext.new()
			d.source_id = int(spec.attacker_id)
			d.target_id = int(tid)
			d.base_amount = maxi(int(spec.base_damage), 0)
			d.deal_modifier_type = int(spec.deal_modifier_type)
			d.take_modifier_type = int(spec.take_modifier_type)
			d.tags = spec.tags
			d.params = spec.params

			api.resolve_damage_immediate(d)
			any = true

	return any
