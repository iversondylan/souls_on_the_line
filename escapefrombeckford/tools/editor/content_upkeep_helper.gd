@tool
class_name ContentUpkeepHelper
extends RefCounted

const ARCANA_COLLECTION_PATH := "uid://dk5tv1hrr615d"
const ARCANUM_CATALOG_PATH := "uid://cd45rlmihsfvb"
const ARCANA_REWARD_POOL_PATH := "uid://c8kt337vs6465"
const STATUS_CATALOG_PATH := "uid://bqr4wekgibhim"

const ARCANA_ROOT := "res://arcana/general"
const STATUS_ROOT := "res://statuses"


static func run_all() -> Dictionary:
	var results := {
		"arcana_catalog": rebuild_arcana_catalogs(),
		"arcana_reward_pool": rebuild_arcana_reward_pool(),
		"status_catalog": rebuild_status_catalog(),
	}
	results["ok"] = bool(results["arcana_catalog"].get("ok", false)) \
		and bool(results["arcana_reward_pool"].get("ok", false)) \
		and bool(results["status_catalog"].get("ok", false))
	return results


static func rebuild_arcana_catalogs() -> Dictionary:
	var found_arcana := _load_resources_recursive(ARCANA_ROOT, Arcanum)
	found_arcana.sort_custom(func(a: Arcanum, b: Arcanum) -> bool:
		return str(a.resource_path) < str(b.resource_path)
	)

	var validation := _validate_resource_ids(found_arcana, "arcanum")
	if !bool(validation.get("ok", false)):
		return validation

	var collection := load(ARCANA_COLLECTION_PATH)
	if !(collection is Arcana):
		return _error_result("Arcana collection at %s is not an Arcana resource." % ARCANA_COLLECTION_PATH)

	var catalog := load(ARCANUM_CATALOG_PATH)
	if !(catalog is ArcanaCatalog):
		return _error_result("Arcanum catalog at %s is not an ArcanaCatalog resource." % ARCANUM_CATALOG_PATH)

	collection.arcana.clear()
	collection.arcana.append_array(found_arcana)
	catalog.arcana.clear()
	catalog.arcana.append_array(found_arcana)

	var save_result := _save_resource(collection)
	if !bool(save_result.get("ok", false)):
		return save_result
	save_result = _save_resource(catalog)
	if !bool(save_result.get("ok", false)):
		return save_result

	return {
		"ok": true,
		"label": "arcanum catalog",
		"count": found_arcana.size(),
	}


static func rebuild_arcana_reward_pool() -> Dictionary:
	var found_arcana := _load_resources_recursive(ARCANA_ROOT, Arcanum)
	found_arcana.sort_custom(func(a: Arcanum, b: Arcanum) -> bool:
		return str(a.resource_path) < str(b.resource_path)
	)

	var validation := _validate_resource_ids(found_arcana, "arcanum")
	if !bool(validation.get("ok", false)):
		return validation

	var pool := load(ARCANA_REWARD_POOL_PATH)
	if !(pool is ArcanaRewardPool):
		return _error_result("Arcana reward pool at %s is not an ArcanaRewardPool resource." % ARCANA_REWARD_POOL_PATH)

	var allowed_ids: Array[String] = []
	for arcanum: Arcanum in found_arcana:
		if arcanum.starter_arcanum:
			continue
		allowed_ids.append(str(arcanum.get_id()))
	allowed_ids.sort()
	pool.allowed_ids = PackedStringArray(allowed_ids)

	var save_result := _save_resource(pool)
	if !bool(save_result.get("ok", false)):
		return save_result

	return {
		"ok": true,
		"label": "arcana reward pool",
		"count": allowed_ids.size(),
	}


static func rebuild_status_catalog() -> Dictionary:
	var found_statuses := _load_resources_recursive(STATUS_ROOT, Status)
	found_statuses.sort_custom(func(a: Status, b: Status) -> bool:
		return str(a.resource_path) < str(b.resource_path)
	)

	var validation := _validate_resource_ids(found_statuses, "status")
	if !bool(validation.get("ok", false)):
		return validation

	var catalog := load(STATUS_CATALOG_PATH)
	if !(catalog is StatusCatalog):
		return _error_result("Status catalog at %s is not a StatusCatalog resource." % STATUS_CATALOG_PATH)

	catalog.statuses.clear()
	catalog.statuses.append_array(found_statuses)

	var save_result := _save_resource(catalog)
	if !bool(save_result.get("ok", false)):
		return save_result

	return {
		"ok": true,
		"label": "status catalog",
		"count": found_statuses.size(),
	}


static func _load_resources_recursive(root_path: String, expected_type) -> Array:
	var results: Array = []
	var dir := DirAccess.open(root_path)
	if dir == null:
		push_error("ContentUpkeepHelper: could not open directory %s" % root_path)
		return results

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while !file_name.is_empty():
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue

		var full_path := "%s/%s" % [root_path, file_name]
		if dir.current_is_dir():
			results.append_array(_load_resources_recursive(full_path, expected_type))
		elif file_name.ends_with(".tres"):
			var resource := load(full_path)
			if resource != null and is_instance_of(resource, expected_type):
				results.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


static func _validate_resource_ids(resources: Array, label: String) -> Dictionary:
	var by_id := {}
	for resource in resources:
		if resource == null:
			continue
		var id := resource.get_id()
		if id == &"":
			return _error_result("Found %s with empty id: %s" % [label, str(resource.resource_path)])
		if by_id.has(id):
			return _error_result(
				"Found duplicate %s id %s in %s and %s" % [
					label,
					str(id),
					str(by_id[id]),
					str(resource.resource_path),
				]
			)
		by_id[id] = str(resource.resource_path)
	return {
		"ok": true,
		"count": resources.size(),
	}


static func _save_resource(resource: Resource) -> Dictionary:
	if resource == null:
		return _error_result("Tried to save a null resource.")
	var path := str(resource.resource_path)
	if path.is_empty():
		return _error_result("Resource %s is missing a resource_path." % resource.get_class())
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		return _error_result("Failed to save %s (err=%s)." % [path, err])
	return {
		"ok": true,
		"path": path,
	}


static func _error_result(message: String) -> Dictionary:
	push_error("ContentUpkeepHelper: %s" % message)
	return {
		"ok": false,
		"error": message,
	}
