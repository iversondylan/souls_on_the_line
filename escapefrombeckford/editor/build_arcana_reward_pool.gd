@tool
extends EditorScript

const POOL_PATH := "res://fighters/Player/arcana_reward_pool.tres"
const ARCANA_ROOT := "res://arcana/general/"

func _run():
	var pool := load(POOL_PATH) as ArcanaRewardPool
	assert(pool, "Failed to load ArcanaRewardPool")
	
	var new_ids := PackedStringArray()
	
	var arcana := _load_all_arcana(ARCANA_ROOT)
	for a in arcana:
		if !a.starter_arcanum:
			new_ids.append(a.id)
	
	# 🔑 THIS IS THE REAL FIX
	pool.allowed_ids = new_ids
	
	var err := ResourceSaver.save(pool, POOL_PATH)
	assert(err == OK, "Failed to save Arcana reward pool")
	
	#print("Arcana reward pool rebuilt and saved (%d ids)." % new_ids.size())


func _load_all_arcana(path: String) -> Array[Arcanum]:
	var result: Array[Arcanum] = []
	var dir := DirAccess.open(path)
	if !dir:
		return result

	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		var full := path + "/" + file

		if dir.current_is_dir() and !file.begins_with("."):
			result.append_array(_load_all_arcana(full))
		elif file.ends_with(".tres"):
			var res := load(full)
			if res is Arcanum:
				result.append(res)

		file = dir.get_next()

	dir.list_dir_end()
	return result
