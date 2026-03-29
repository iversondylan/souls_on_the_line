@tool
class_name ContentUpkeepHelper
extends RefCounted

## ============================================================
## USER-EDITABLE PATHS
## Change these if you want the upkeep outputs or scan roots to
## live somewhere else.
## Existing files at these paths are updated in place.
## Missing files at these paths are created automatically.
## ============================================================
const ARCANUM_CATALOG_PATH := "res://arcana/_core/arcanum_catalog.tres"
const ARCANA_REWARD_POOL_PATH := "res://character_profiles/Cole/arcana_reward_pool.tres"
const STATUS_CATALOG_PATH := "res://statuses/_core/status_catalog.tres"

const ARCANA_ROOT := "res://arcana/"
const STATUS_ROOT := "res://statuses/"

## Script source is scanned for `const ID = &"..."` or `:=`.
const ID_CONST_PATTERN := 'const\\s+ID\\s*(?::=|=)\\s*&"([^"]+)"'


func run_all() -> Dictionary:
	var results := {
		"arcana_catalog": rebuild_arcana_catalogs(),
		"arcana_reward_pool": rebuild_arcana_reward_pool(),
		"status_catalog": rebuild_status_catalog(),
	}
	results["ok"] = bool(results["arcana_catalog"].get("ok", false)) \
		and bool(results["arcana_reward_pool"].get("ok", false)) \
		and bool(results["status_catalog"].get("ok", false))
	return results


func rebuild_arcana_catalogs() -> Dictionary:
	var found_arcana := _load_resources_recursive(ARCANA_ROOT, Arcanum)
	found_arcana.sort_custom(func(a: Arcanum, b: Arcanum) -> bool:
		return str(a.resource_path) < str(b.resource_path)
	)

	var validation := _validate_resource_ids(found_arcana, "arcanum")
	if !bool(validation.get("ok", false)):
		return validation

	var catalog := _load_or_create_resource(
		ARCANUM_CATALOG_PATH,
		func() -> Resource: return ArcanaCatalog.new(),
		"arcanum catalog"
	)
	if !(catalog is ArcanaCatalog):
		return _error_result("Arcanum catalog at %s is not an ArcanaCatalog resource." % ARCANUM_CATALOG_PATH)

	catalog.arcana.clear()
	catalog.arcana.append_array(found_arcana)

	var save_result := _save_resource(catalog, ARCANUM_CATALOG_PATH)
	if !bool(save_result.get("ok", false)):
		return save_result

	return {
		"ok": true,
		"label": "arcanum catalog",
		"count": found_arcana.size(),
	}


func rebuild_arcana_reward_pool() -> Dictionary:
	var found_arcana := _load_resources_recursive(ARCANA_ROOT, Arcanum)
	found_arcana.sort_custom(func(a: Arcanum, b: Arcanum) -> bool:
		return str(a.resource_path) < str(b.resource_path)
	)

	var validation := _validate_resource_ids(found_arcana, "arcanum")
	if !bool(validation.get("ok", false)):
		return validation

	var pool := _load_or_create_resource(
		ARCANA_REWARD_POOL_PATH,
		func() -> Resource: return ArcanaRewardPool.new(),
		"arcana reward pool"
	)
	if !(pool is ArcanaRewardPool):
		return _error_result("Arcana reward pool at %s is not an ArcanaRewardPool resource." % ARCANA_REWARD_POOL_PATH)

	var allowed_ids: Array[String] = []
	for arcanum: Arcanum in found_arcana:
		if arcanum.starter_arcanum:
			continue
		allowed_ids.append(str(_extract_resource_id(arcanum)))
	allowed_ids.sort()
	pool.allowed_ids = PackedStringArray(allowed_ids)

	var save_result := _save_resource(pool, ARCANA_REWARD_POOL_PATH)
	if !bool(save_result.get("ok", false)):
		return save_result

	return {
		"ok": true,
		"label": "arcana reward pool",
		"count": allowed_ids.size(),
	}


func rebuild_status_catalog() -> Dictionary:
	var found_statuses := _load_resources_recursive(STATUS_ROOT, Status)
	found_statuses.sort_custom(func(a: Status, b: Status) -> bool:
		return str(a.resource_path) < str(b.resource_path)
	)

	var validation := _validate_resource_ids(found_statuses, "status")
	if !bool(validation.get("ok", false)):
		return validation

	var catalog := _load_or_create_resource(
		STATUS_CATALOG_PATH,
		func() -> Resource: return StatusCatalog.new(),
		"status catalog"
	)
	if !(catalog is StatusCatalog):
		return _error_result("Status catalog at %s is not a StatusCatalog resource." % STATUS_CATALOG_PATH)

	catalog.statuses.clear()
	catalog.statuses.append_array(found_statuses)

	var save_result := _save_resource(catalog, STATUS_CATALOG_PATH)
	if !bool(save_result.get("ok", false)):
		return save_result

	return {
		"ok": true,
		"label": "status catalog",
		"count": found_statuses.size(),
	}


func _load_resources_recursive(root_path: String, expected_type) -> Array:
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


func _validate_resource_ids(resources: Array, label: String) -> Dictionary:
	var by_id := {}
	for resource in resources:
		if resource == null:
			continue
		var id := _extract_resource_id(resource)
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


func _extract_resource_id(resource: Resource) -> StringName:
	if resource == null:
		return &""
	var script := resource.get_script() as Script
	if script == null:
		push_warning("ContentUpkeepHelper: resource %s is missing a script" % str(resource.resource_path))
		return &""
	var script_path := str(script.resource_path)
	if script_path.is_empty():
		push_warning("ContentUpkeepHelper: resource %s has a script with no path" % str(resource.resource_path))
		return &""
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		push_warning("ContentUpkeepHelper: failed to open script %s" % script_path)
		return &""
	var source := file.get_as_text()
	var regex := RegEx.new()
	var err := regex.compile(ID_CONST_PATTERN)
	if err != OK:
		push_warning("ContentUpkeepHelper: failed to compile ID regex")
		return &""
	var match := regex.search(source)
	if match == null or match.get_group_count() < 1:
		push_warning("ContentUpkeepHelper: could not find const ID in %s" % script_path)
		return &""
	return StringName(match.get_string(1))


func _load_or_create_resource(path: String, factory: Callable, label: String) -> Resource:
	var resource: Resource = null
	if ResourceLoader.exists(path):
		resource = load(path)
	if resource != null:
		return resource
	if !factory.is_valid():
		push_error("ContentUpkeepHelper: no factory provided for %s at %s" % [label, path])
		return null
	resource = factory.call()
	if resource == null:
		push_error("ContentUpkeepHelper: failed to create %s at %s" % [label, path])
		return null
	resource.resource_path = path
	return resource


func _save_resource(resource: Resource, path_override: String = "") -> Dictionary:
	if resource == null:
		return _error_result("Tried to save a null resource.")
	var path := path_override if !path_override.is_empty() else str(resource.resource_path)
	if path.is_empty():
		return _error_result("Resource %s is missing a resource_path." % resource.get_class())
	var err := ResourceSaver.save(resource, path)
	if err != OK:
		return _error_result("Failed to save %s (err=%s)." % [path, err])
	return {
		"ok": true,
		"path": path,
	}


func _error_result(message: String) -> Dictionary:
	push_error("ContentUpkeepHelper: %s" % message)
	return {
		"ok": false,
		"error": message,
	}
