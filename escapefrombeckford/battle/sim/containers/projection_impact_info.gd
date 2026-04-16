class_name ProjectionImpactInfo extends RefCounted

var known: bool = false
var target_ids: PackedInt32Array = PackedInt32Array()


func _init(_known := false, _target_ids: PackedInt32Array = PackedInt32Array()) -> void:
	known = bool(_known)
	target_ids = PackedInt32Array(_target_ids)


func clone():
	return get_script().new(known, target_ids)

func merged_with(other):
	var merged_ids := PackedInt32Array()
	var seen := {}

	for ids in [target_ids, other.target_ids if other != null else PackedInt32Array()]:
		for raw_id in ids:
			var cid := int(raw_id)
			if cid <= 0 or seen.has(cid):
				continue
			seen[cid] = true
			merged_ids.append(cid)

	return get_script().new(
		known or (other != null and other.known),
		merged_ids
	)
