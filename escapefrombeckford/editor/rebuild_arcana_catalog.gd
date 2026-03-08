@tool
extends EditorScript

const CATALOG_PATH := "res://arcana/arcana_catalog.tres"
const ARCANA_ROOT := "res://arcana/general"

func _run() -> void:
	var catalog := load(CATALOG_PATH)
	if !(catalog is Arcana):
		push_error("Catalog at %s is not an Arcana resource." % CATALOG_PATH)
		return
	
	var found_arcana := _load_arcana_recursive(ARCANA_ROOT)
	
	catalog.arcana.clear()
	catalog.arcana.append_array(found_arcana)
	
	var err := ResourceSaver.save(catalog)
	if err != OK:
		push_error("Failed to save arcana catalog.")
		return
	
	#print("Arcana catalog rebuilt: %d arcana found." % found_arcana.size())
	ResourceSaver.save(catalog, catalog.resource_path)
	#print("Arcana catalog saved.")


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
