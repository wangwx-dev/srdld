class_name CircleOcclusionDriver
extends Node
# Apply only to wall/tree material overrides; never to the character or floor.
@export var subject: Node3D
@export var camera: Camera3D
@export var occluder_materials: Array[ShaderMaterial]
@export var focus_height := 0.95
@export var radius_pixels := 150.0
func _process(_delta: float) -> void:
    if not is_instance_valid(subject) or not is_instance_valid(camera): return
    var focus := subject.global_position + Vector3.UP * focus_height
    var uv := camera.unproject_position(focus) / camera.get_viewport().get_visible_rect().size
    var depth := -(camera.global_transform.affine_inverse() * focus).z
    for material in occluder_materials:
        material.set_shader_parameter("subject_screen_uv", uv)
        material.set_shader_parameter("subject_view_depth", depth)
        material.set_shader_parameter("radius_pixels", radius_pixels)
        material.set_shader_parameter("enabled", not camera.is_position_behind(focus))
