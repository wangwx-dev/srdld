extends SceneTree
func _initialize() -> void: call_deferred("render_room")
func render_room() -> void:
    root.size=Vector2i(1920,1080)
    DisplayServer.window_set_size(Vector2i(1920,1080))
    var world: Node3D=load("res://assets/room_realtime.glb").instantiate()
    root.add_child(world)
    # Runtime exposure compensation for bright linen; preserve imported PBR textures.
    for mesh in world.find_children("*", "MeshInstance3D", true, false):
        for surface in range(mesh.mesh.get_surface_count()):
            var material=mesh.mesh.surface_get_material(surface)
            if material is StandardMaterial3D and material.resource_name=="linen":
                var calibrated=material.duplicate()
                calibrated.albedo_color=Color(0.70,0.76,0.78,1)
                mesh.set_surface_override_material(surface,calibrated)
    var character: Node3D=load("res://assets/female_rigged.glb").instantiate()
    character.position=Vector3(0.55,0,-1.82)
    character.rotation.y=PI
    root.add_child(character)
    for player in character.find_children("*", "AnimationPlayer", true, false):
        player.play("Sit_Desk")
        player.advance(0.0)
    var env := WorldEnvironment.new()
    env.environment=Environment.new()
    env.environment.background_mode=Environment.BG_COLOR
    env.environment.background_color=Color(0.82,0.79,0.72)
    env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    env.environment.ambient_light_color=Color(1.0,0.94,0.84)
    env.environment.ambient_light_energy=0.42
    env.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    root.add_child(env)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees=Vector3(-55,-30,0)
    sun.light_energy=0.48
    sun.light_color=Color(1.0,0.92,0.80)
    sun.shadow_enabled=true
    root.add_child(sun)
    var fill:=OmniLight3D.new()
    fill.position=Vector3(0,3,0)
    fill.omni_range=10
    fill.light_energy=0.18
    fill.light_color=Color(1.0,0.86,0.70)
    root.add_child(fill)
    var camera := Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=8.325
    var target:=Vector3(-1,1.45,-1)
    camera.position=target+Vector3(10,14.1421356,10)
    root.add_child(camera)
    camera.look_at(target)
    camera.current=true
    for i in range(8):await process_frame
    root.get_texture().get_image().save_png("res://../renders/04_godot_room_realtime_v2.png")
    print("REAL_GODOT_ROOM_RENDER_FINISHED")
    quit()
