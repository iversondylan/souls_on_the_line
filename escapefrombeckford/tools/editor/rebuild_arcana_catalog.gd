@tool
extends EditorScript

const ARCANA_COLLECTION_PATH := "uid://dk5tv1hrr615d"
const ARCANUM_CATALOG_PATH := "uid://cd45rlmihsfvb"
const ARCANA_ROOT := "res://arcana/general"

func _run() -> void:
	var found_arcana := _load_arcana_recursive(ARCANA_ROOT)
	var collection := load(ARCANA_COLLECTION_PATH)
	if !(collection is Arcana):
		push_error("Catalog at %s is not an Arcana resource." % ARCANA_COLLECTION_PATH)
		return

	var catalog := load(ARCANUM_CATALOG_PATH)
	if !(catalog is ArcanaCatalog):
		push_error("Catalog at %s is not an ArcanaCatalog resource." % ARCANUM_CATALOG_PATH)
		return

	collection.arcana.clear()
	collection.arcana.append_array(found_arcana)
	catalog.arcana.clear()
	catalog.arcana.append_array(found_arcana)

	var err := ResourceSaver.save(collection, collection.resource_path)
	if err != OK:
		push_error("Failed to save arcana collection.")
		return

	err = ResourceSaver.save(catalog, catalog.resource_path)
	if err != OK:
		push_error("Failed to save arcanum catalog.")
		return


func _load_arcana_recursive(path: String) -> Array[Arcanum]:
	var results: Array[Arcanum] = []
	
	var dir := DirAccess.open(path)
	if dir == null:
		push_error("Could not open directory: %s" % path)
		return results
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		
		var full_path := path + "/" + file_name
		
		if dir.current_is_dir():
			results.append_array(_load_arcana_recursive(full_path))
		elif file_name.ends_with(".tres"):
			var res := load(full_path)
			if res is Arcanum:
				results.append(res)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return results
