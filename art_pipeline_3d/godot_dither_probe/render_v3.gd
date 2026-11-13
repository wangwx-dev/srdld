extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
    root.size=Vector2i(1920,1400)
    DisplayServer.window_set_size(Vector2i(1920,1400))
    var room:Node3D=load("res://assets/room_realtime.glb").instantiate()
    root.add_child(room)
    for node in room.find_children("wall_low_front*", "Node3D", true, false):node.visible=false
    var audit={"engine":Engine.get_version_info(),"renderer":RenderingServer.get_video_adapter_name(),"characters":{}}
    for sex in ["female","male"]:
        var c:Node3D=load("res://assets/"+sex+"_rigged.glb").instantiate()
        root.add_child(c)
        c.position=Vector3(-1.1 if sex=="female" else 0.0,0,0.5)
        var skeleton:Skeleton3D=c.find_children("*","Skeleton3D",true,false)[0]
        var player:AnimationPlayer=c.find_children("*","AnimationPlayer",true,false)[0]
        var mats=[]
        for mesh in c.find_children("*","MeshInstance3D",true,false):
            for i in range(mesh.mesh.get_surface_count()):
                var m=mesh.mesh.surface_get_material(i)
                if "Skin_" in m.resource_name:
                    m=m.duplicate()
                    m.rim_enabled=true
                    m.rim=.15
                    m.rim_tint=.80
                    mesh.set_surface_override_material(i,m)
                mats.append({"name":m.resource_name,"roughness_factor":m.roughness,"metallic":m.metallic,"normal_enabled":m.normal_enabled,"has_albedo":m.albedo_texture!=null,"has_roughness":m.roughness_texture!=null,"warm_skin_rim":m.rim_enabled})
        var checks={}
        for action in ["Idle","Sit_Desk","Sleep_Bed","Read_Book","Pet_Cat"]:
            player.play(action)
            player.advance(0.01)
            await process_frame
            skeleton.force_update_all_bone_transforms()
            var basis=skeleton.get_bone_global_pose(skeleton.find_bone("Head")).basis
            var morph_values=[]
            for mesh in c.find_children("*","MeshInstance3D",true,false):
                for i in range(mesh.get_blend_shape_count()):morph_values.append({"name":mesh.mesh.get_blend_shape_name(i),"value":mesh.get_blend_shape_value(i)})
            checks[action]={"morph_values":morph_values,"head_axis_lengths":[basis.x.length(),basis.y.length(),basis.z.length()],"head_determinant":basis.determinant()}
        audit["characters"][sex]={"bones":skeleton.get_bone_count(),"clips":Array(player.get_animation_list()),"materials":mats,"poses":checks}
        player.play("Idle")
        player.advance(0.0)
    var we=WorldEnvironment.new()
    we.environment=Environment.new()
    we.environment.background_mode=Environment.BG_COLOR
    we.environment.background_color=Color(.66,.66,.61)
    we.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
    we.environment.ambient_light_color=Color(1,.94,.84)
    we.environment.ambient_light_energy=.25
    we.environment.tonemap_mode=Environment.TONE_MAPPER_FILMIC
    root.add_child(we)
    var key=DirectionalLight3D.new()
    key.rotation_degrees=Vector3(-45,-25,0)
    key.light_energy=.38
    key.light_color=Color(1,.91,.79)
    key.shadow_enabled=true
    root.add_child(key)
    var fill=OmniLight3D.new()
    fill.position=Vector3(0,3,2)
    fill.omni_range=12
    fill.light_energy=.08
    fill.light_color=Color(1,.88,.74)
    root.add_child(fill)
    var camera=Camera3D.new()
    camera.projection=Camera3D.PROJECTION_ORTHOGONAL
    camera.size=2.6
    var target=Vector3(-.55,.83,.45)
    camera.position=target+Vector3(2.0,2.3,8)
    root.add_child(camera)
    camera.look_at(target)
    camera.current=true
    for i in range(20):await process_frame
    root.get_texture().get_image().save_png("res://../renders/03_godot_characters_v3.png")
    var file=FileAccess.open("res://../evidence/godot_runtime.json",FileAccess.WRITE)
    file.store_string(JSON.stringify(audit,"  "))
    print("V3_REAL_GODOT_RENDER_DONE")
    quit()
