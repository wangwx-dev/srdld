extends ColorRect
class_name RoomComposite

var _mat: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader: Shader = load("res://shaders/room_depth.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat


func set_pair(slot: String, color_path: String, depth_path: String) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter(slot + "_tex", _tex(color_path))
	if depth_path != "":
		_mat.set_shader_parameter(slot + "_z", _tex(depth_path))


func set_hover(slot_id: int) -> void:
	if _mat != null:
		_mat.set_shader_parameter("hover_slot", slot_id)


func _tex(path: String) -> Texture2D:
	var loaded: Resource = load(path)
	if loaded is Texture2D:
		return loaded
	return null
