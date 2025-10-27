class_name Status extends Resource

signal status_applied(status: Status)
signal status_changed()

enum ProcType {START_OF_TURN, END_OF_TURN, EVENT_BASED}
enum StackType {NONE, INTENSITY, DURATION}
enum AuraType {NONE, ALLIES, ENEMIES}

@export_group("Status Data")
@export var id: String
@export var proc_type: ProcType
@export var stack_type: StackType
@export var aura_type: AuraType
@export var can_expire: bool
@export var duration: int : set = _set_duration
@export var intensity: int : set = _set_intensity
@export var secondary_status: Status
@export_group("Status Visuals")
@export var icon: Texture
@export_multiline var tooltip: String

func init_status(_target: Node) -> void:
	pass

func apply_status(_target: Node) -> void:
	status_applied.emit(self)

func get_tooltip() -> String:
	return tooltip

func _set_duration(new_duration: int) -> void:
	duration = new_duration
	status_changed.emit()

func _set_intensity(new_intensity: int) -> void:
	intensity = new_intensity
	status_changed.emit()

func _on_status_changed(target: Node) -> void:
	print("status.gd _on_status_changed(): virtual function called")
