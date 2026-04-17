class_name CardSnapshot extends Resource

const SERIALIZED_KIND_STRING_NAME := "string_name"
const SERIALIZED_KIND_COLOR := "color"
const SERIALIZED_KIND_VECTOR2 := "vector2"
const SERIALIZED_KIND_VECTOR2I := "vector2i"
const SERIALIZED_KIND_VECTOR3 := "vector3"
const SERIALIZED_KIND_PACKED_STRING_ARRAY := "packed_string_array"
const SERIALIZED_KIND_PACKED_INT32_ARRAY := "packed_int32_array"
const SERIALIZED_KIND_EXTERNAL_RESOURCE := "external_resource"
const SERIALIZED_KIND_SCRIPTED_RESOURCE := "scripted_resource"

@export var template_hint_path: String = ""
@export var card: CardData


static func from_card(source_card: CardData) -> CardSnapshot:
	if source_card == null:
		return null
	var snapshot := CardSnapshot.new()
	snapshot.template_hint_path = String(source_card.base_proto_path if source_card.base_proto_path != "" else source_card.resource_path)
	snapshot.card = source_card.duplicate(true) as CardData
	if snapshot.card != null:
		snapshot.card.base_proto_path = snapshot.template_hint_path
		snapshot.card.ensure_uid()
	return snapshot


func instantiate_card() -> CardData:
	if card == null:
		return null
	var restored := card.make_runtime_instance()
	if restored == null:
		return null
	if restored.base_proto_path == "":
		restored.base_proto_path = template_hint_path
	restored.ensure_uid()
	return restored


static func card_to_serialized_snapshot(source_card: CardData) -> Dictionary:
	return to_serialized_dict(from_card(source_card))


static func instantiate_from_serialized_dict(data: Dictionary) -> CardData:
	var snapshot := from_serialized_dict(data)
	if snapshot == null:
		return null
	return snapshot.instantiate_card()


static func from_serialized_dict(data: Dictionary) -> CardSnapshot:
	if data.is_empty():
		return null
	var snapshot := CardSnapshot.new()
	snapshot.template_hint_path = str(data.get("template_hint_path", ""))
	snapshot.card = deserialize_card_data(_as_dictionary(data.get("card", {})))
	if snapshot.card == null:
		return null
	return snapshot


static func to_serialized_dict(snapshot: CardSnapshot) -> Dictionary:
	return {
		"template_hint_path": str(snapshot.template_hint_path if snapshot != null else ""),
		"card": serialize_card_data(snapshot.card if snapshot != null else null),
	}


static func deserialize_card_data(data: Dictionary) -> CardData:
	if data.is_empty():
		return null
	var card_data := CardData.new()
	card_data.id = StringName(str(data.get("id", "")))
	card_data.uid = str(data.get("uid", ""))
	card_data.version = int(data.get("version", 1))
	card_data.base_proto_path = str(data.get("base_proto_path", ""))
	card_data.card_type = int(data.get("card_type", 0)) as CardData.CardType
	card_data.target_type = int(data.get("target_type", 0)) as CardData.TargetType
	card_data.rarity = int(data.get("rarity", 0)) as CardData.Rarity
	card_data.name = str(data.get("name", ""))
	card_data.deplete = bool(data.get("deplete", false))
	card_data.starter_card = bool(data.get("starter_card", false))
	card_data.summon_release_overload = int(data.get("summon_release_overload", 2))
	card_data.description = str(data.get("description", ""))
	card_data.cost = int(data.get("cost", 0))
	card_data.overload = int(data.get("overload", 0))
	card_data.texture = _load_external_resource_ref(str(data.get("texture_ref", ""))) as Texture2D
	card_data.actions = _decode_card_action_array(data.get("actions", []))
	card_data.ensure_id()
	card_data.ensure_uid()
	return card_data


static func serialize_card_data(card_data: CardData) -> Dictionary:
	if card_data == null:
		return {}
	card_data.ensure_id()
	card_data.ensure_uid()
	var encoded_actions: Array[Dictionary] = []
	for action in card_data.actions:
		var action_dto := _encode_scripted_resource(action)
		if action_dto.is_empty():
			continue
		encoded_actions.append(action_dto)
	return {
		"id": str(card_data.id),
		"uid": str(card_data.uid),
		"version": int(card_data.version),
		"base_proto_path": str(card_data.base_proto_path),
		"card_type": int(card_data.card_type),
		"target_type": int(card_data.target_type),
		"rarity": int(card_data.rarity),
		"name": str(card_data.name),
		"deplete": bool(card_data.deplete),
		"starter_card": bool(card_data.starter_card),
		"summon_release_overload": int(card_data.summon_release_overload),
		"description": str(card_data.description),
		"cost": int(card_data.cost),
		"overload": int(card_data.overload),
		"texture_ref": _external_resource_ref_string(card_data.texture),
		"actions": encoded_actions,
	}


static func _decode_card_action_array(values: Variant) -> Array[CardAction]:
	var actions: Array[CardAction] = []
	if typeof(values) != TYPE_ARRAY:
		return actions
	for value in values:
		var action := _decode_scripted_resource(value) as CardAction
		if action != null:
			actions.append(action)
	return actions


static func _encode_scripted_resource(resource: Resource) -> Dictionary:
	if resource == null:
		return {}
	var script := resource.get_script() as Script
	if script == null:
		push_warning("CardSnapshot: missing script for resource class=%s" % resource.get_class())
		return {}
	var script_uid := _script_uid_for_script(script)
	if script_uid.is_empty():
		push_warning("CardSnapshot: missing script uid for %s" % str(script.resource_path))
		return {}
	return {
		"script_uid": script_uid,
		"values": _encode_resource_values(resource),
	}


static func _decode_scripted_resource(value: Variant) -> Resource:
	if typeof(value) != TYPE_DICTIONARY:
		return null
	var data := value as Dictionary
	var script_uid := str(data.get("script_uid", ""))
	if script_uid.is_empty():
		push_warning("CardSnapshot: scripted resource is missing script_uid")
		return null
	var script_path := _script_path_for_uid(script_uid)
	if script_path.is_empty():
		push_warning("CardSnapshot: unable to resolve script uid %s" % script_uid)
		return null
	var script := load(script_path) as Script
	if script == null:
		push_warning("CardSnapshot: failed to load script at %s" % script_path)
		return null
	var resource = script.new()
	if !(resource is Resource):
		push_warning("CardSnapshot: script %s did not instantiate a Resource" % script_path)
		return null
	_apply_decoded_resource_values(resource, _as_dictionary(data.get("values", {})))
	return resource


static func _encode_resource_values(resource: Resource) -> Dictionary:
	var values := {}
	for property_data in resource.get_property_list():
		if !_should_encode_resource_property(property_data):
			continue
		var property_name := str(property_data.name)
		values[property_name] = _encode_variant_value(resource.get(property_name))
	return values


static func _apply_decoded_resource_values(resource: Resource, values: Dictionary) -> void:
	for key in values.keys():
		var property_name := str(key)
		if !_resource_has_property(resource, property_name):
			continue
		resource.set(property_name, _decode_variant_value(values[key]))


static func _resource_has_property(resource: Resource, property_name: String) -> bool:
	if resource == null or property_name.is_empty():
		return false
	for property_data in resource.get_property_list():
		if str(property_data.get("name", "")) == property_name:
			return true
	return false


static func _should_encode_resource_property(property_data: Dictionary) -> bool:
	var property_name := str(property_data.get("name", ""))
	if property_name.is_empty():
		return false
	if property_name == "metadata/_custom_type_script":
		return false
	if property_name in ["resource_local_to_scene", "resource_name", "resource_path", "resource_scene_unique_id", "script"]:
		return false
	var usage := int(property_data.get("usage", 0))
	if (usage & PROPERTY_USAGE_STORAGE) == 0:
		return false
	return true


static func _encode_variant_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value
		TYPE_STRING_NAME:
			return {
				"__kind": SERIALIZED_KIND_STRING_NAME,
				"value": str(value),
			}
		TYPE_COLOR:
			var color := value as Color
			return {
				"__kind": SERIALIZED_KIND_COLOR,
				"r": color.r,
				"g": color.g,
				"b": color.b,
				"a": color.a,
			}
		TYPE_VECTOR2:
			var vector2 := value as Vector2
			return {
				"__kind": SERIALIZED_KIND_VECTOR2,
				"x": float(vector2.x),
				"y": float(vector2.y),
			}
		TYPE_VECTOR2I:
			var vector2i := value as Vector2i
			return {
				"__kind": SERIALIZED_KIND_VECTOR2I,
				"x": int(vector2i.x),
				"y": int(vector2i.y),
			}
		TYPE_VECTOR3:
			var vector3 := value as Vector3
			return {
				"__kind": SERIALIZED_KIND_VECTOR3,
				"x": float(vector3.x),
				"y": float(vector3.y),
				"z": float(vector3.z),
			}
		TYPE_ARRAY:
			var encoded_array: Array = []
			for entry in value:
				encoded_array.append(_encode_variant_value(entry))
			return encoded_array
		TYPE_DICTIONARY:
			var encoded_dict := {}
			for key in value.keys():
				encoded_dict[str(key)] = _encode_variant_value(value[key])
			return encoded_dict
		TYPE_PACKED_STRING_ARRAY:
			return {
				"__kind": SERIALIZED_KIND_PACKED_STRING_ARRAY,
				"values": _encode_packed_string_array(value),
			}
		TYPE_PACKED_INT32_ARRAY:
			return {
				"__kind": SERIALIZED_KIND_PACKED_INT32_ARRAY,
				"values": _encode_int_array(value),
			}
		TYPE_OBJECT:
			if value is Resource:
				var resource := value as Resource
				if _should_store_resource_as_reference(resource):
					return {
						"__kind": SERIALIZED_KIND_EXTERNAL_RESOURCE,
						"path": _external_resource_ref_string(resource),
					}
				return {
					"__kind": SERIALIZED_KIND_SCRIPTED_RESOURCE,
					"data": _encode_scripted_resource(resource),
				}
	push_warning("CardSnapshot: unsupported save variant type %s" % typeof(value))
	return null


static func _decode_variant_value(value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		var decoded_array: Array = []
		for entry in value:
			decoded_array.append(_decode_variant_value(entry))
		return decoded_array
	if typeof(value) != TYPE_DICTIONARY:
		return value

	var dict := value as Dictionary
	var kind := str(dict.get("__kind", ""))
	match kind:
		"":
			var decoded_dict := {}
			for key in dict.keys():
				decoded_dict[str(key)] = _decode_variant_value(dict[key])
			return decoded_dict
		SERIALIZED_KIND_STRING_NAME:
			return StringName(str(dict.get("value", "")))
		SERIALIZED_KIND_COLOR:
			return Color(
				float(dict.get("r", 1.0)),
				float(dict.get("g", 1.0)),
				float(dict.get("b", 1.0)),
				float(dict.get("a", 1.0))
			)
		SERIALIZED_KIND_VECTOR2:
			return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
		SERIALIZED_KIND_VECTOR2I:
			return Vector2i(int(dict.get("x", 0)), int(dict.get("y", 0)))
		SERIALIZED_KIND_VECTOR3:
			return Vector3(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)), float(dict.get("z", 0.0)))
		SERIALIZED_KIND_PACKED_STRING_ARRAY:
			return _decode_packed_string_array(dict.get("values", []))
		SERIALIZED_KIND_PACKED_INT32_ARRAY:
			return PackedInt32Array(_decode_int_array(dict.get("values", [])))
		SERIALIZED_KIND_EXTERNAL_RESOURCE:
			return _load_external_resource_ref(str(dict.get("path", "")))
		SERIALIZED_KIND_SCRIPTED_RESOURCE:
			return _decode_scripted_resource(dict.get("data", {}))
	return dict


static func _should_store_resource_as_reference(resource: Resource) -> bool:
	if resource == null:
		return true
	return !str(resource.resource_path).is_empty() or resource.get_script() == null or resource is Sound or resource is PackedScene


static func _external_resource_ref_string(resource: Resource) -> String:
	if resource == null:
		return ""
	var path := str(resource.resource_path)
	if path.is_empty():
		return ""
	if path.begins_with("uid://"):
		return path
	var uid := ResourceLoader.get_resource_uid(path)
	if uid > 0:
		return ResourceUID.id_to_text(uid)
	return path


static func _load_external_resource_ref(path: String) -> Resource:
	if path.is_empty():
		return null
	var resource := load(path) as Resource
	if resource == null:
		push_warning("CardSnapshot: failed to load external resource %s" % path)
	return resource


static func _script_uid_for_script(script: Script) -> String:
	if script == null:
		return ""
	var uid_path := "%s.uid" % str(script.resource_path)
	if !FileAccess.file_exists(uid_path):
		return ""
	var file := FileAccess.open(uid_path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text().strip_edges()


static func _script_path_for_uid(script_uid: String) -> String:
	if script_uid.is_empty():
		return ""
	return _find_script_path_for_uid(script_uid, "res://")


static func _find_script_path_for_uid(script_uid: String, local_dir: String) -> String:
	var dir := DirAccess.open(ProjectSettings.globalize_path(local_dir))
	if dir == null:
		return ""
	dir.list_dir_begin()
	var entry := dir.get_next()
	while !entry.is_empty():
		var child_path := _join_local_path(local_dir, entry)
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				var nested_path := _find_script_path_for_uid(script_uid, child_path)
				if !nested_path.is_empty():
					dir.list_dir_end()
					return nested_path
		elif entry.ends_with(".gd.uid"):
			var file := FileAccess.open(child_path, FileAccess.READ)
			if file != null and file.get_as_text().strip_edges() == script_uid:
				dir.list_dir_end()
				return child_path.trim_suffix(".uid")
		entry = dir.get_next()
	dir.list_dir_end()
	return ""


static func _join_local_path(base_path: String, child: String) -> String:
	if base_path.ends_with("://"):
		return "%s%s" % [base_path, child]
	if base_path.ends_with("/"):
		return "%s%s" % [base_path, child]
	return "%s/%s" % [base_path, child]


static func _encode_packed_string_array(values: PackedStringArray) -> Array[String]:
	var encoded: Array[String] = []
	for value in values:
		encoded.append(str(value))
	return encoded


static func _decode_packed_string_array(values: Variant) -> PackedStringArray:
	var decoded := PackedStringArray()
	if typeof(values) != TYPE_ARRAY:
		return decoded
	for value in values:
		decoded.append(str(value))
	return decoded


static func _encode_int_array(values: Variant) -> Array[int]:
	var encoded: Array[int] = []
	if typeof(values) != TYPE_ARRAY and typeof(values) != TYPE_PACKED_INT32_ARRAY:
		return encoded
	for value in values:
		encoded.append(int(value))
	return encoded


static func _decode_int_array(values: Variant) -> Array[int]:
	var decoded: Array[int] = []
	if typeof(values) != TYPE_ARRAY:
		return decoded
	for value in values:
		decoded.append(int(value))
	return decoded


static func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}
