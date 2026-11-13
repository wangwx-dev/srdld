extends SceneTree
func _initialize() -> void: call_deferred("demo")
func demo() -> void:
    root.size=Vector2i(1280,720)
    DisplayServer.window_set_size(Vector2i(1280,720))
    var world := Node3D.new()
    root.add_child(world)
    var env := WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(0.42,0.45,0.43)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color(0.9,0.86,0.75)
    env.environment.ambient_light_energy=0.7
    world.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-55,-30,0)
    sun.light_energy=1.2
    world.add_child(sun)
    var character:Node3D=load("res://assets/female_rigged.glb").instantiate()
    world.add_child(character)
    for player in character.find_children("*", "AnimationPlayer", true, false):
        player.play("Idle")
        player.advance(0.0)
    var camera := Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=4.6
    camera.position=Vector3(6,9.435,6)
    world.add_child(camera)
    camera.look_at(Vector3(0,0.95,0))
    camera.current=true
    var floor_mesh := MeshInstance3D.new()
    var floor_box:=BoxMesh.new()
    floor_box.size=Vector3(6,0.12,5)
    floor_mesh.mesh=floor_box
    floor_mesh.position=Vector3(0,-0.08,0)
    var floor_material:=StandardMaterial3D.new()
    floor_material.albedo_color=Color(0.55,0.4,0.26)
    floor_mesh.material_override=floor_material
    world.add_child(floor_mesh)
    var wall:=MeshInstance3D.new()
    var wall_box:=BoxMesh.new()
    wall_box.size=Vector3(3.8,2.8,0.2)
    wall.mesh=wall_box
    wall.position=Vector3(0,1.4,0.65)
    var material:=ShaderMaterial.new()
    material.shader=load("res://circle_dither.gdshader")
    material.set_shader_parameter("albedo_tex",load("res://wall_diff.jpg"))
    material.set_shader_parameter("roughness_tex",load("res://wall_rough.jpg"))
    material.set_shader_parameter("normal_tex",load("res://wall_normal.jpg"))
    wall.material_override=material
    world.add_child(wall)
    await process_frame
    await process_frame
    var focus:=Vector3(0,0.9,0)
    material.set_shader_parameter("subject_screen_uv",camera.unproject_position(focus)/root.get_visible_rect().size)
    material.set_shader_parameter("subject_view_depth",-(camera.global_transform.affine_inverse()*focus).z)
    material.set_shader_parameter("radius_pixels",175.0)
    material.set_shader_parameter("enabled",false)
    for i in range(5):await process_frame
    root.get_texture().get_image().save_png("res://../renders/godot_occlusion_before.png")
    material.set_shader_parameter("enabled",true)
    for i in range(5):await process_frame
    root.get_texture().get_image().save_png("res://../renders/godot_occlusion_after.png")
    print("REAL_GODOT_DITHER_RENDER_FINISHED")
    quit()
