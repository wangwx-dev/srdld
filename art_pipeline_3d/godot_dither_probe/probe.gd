extends SceneTree
var report := {}
func _initialize() -> void:
    call_deferred("run_probe")
func inspect(n: Node, result: Dictionary) -> void:
    if n is Skeleton3D:
        result["skeletons"].append({"name":n.name,"bones":n.get_bone_count()})
    if n is AnimationPlayer:
        result["animation_players"].append(Array(n.get_animation_list()))
        for a in n.get_animation_list():
            if a != "RESET":
                n.play(a)
                n.advance(0.5)
    if n is MeshInstance3D:
        result["meshes"] += 1
        if n.mesh:
            for s in range(n.mesh.get_surface_count()):
                var arrays = n.mesh.surface_get_arrays(s)
                result["triangles"] += arrays[Mesh.ARRAY_INDEX].size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size() / 3
                if n.mesh.surface_get_material(s) is BaseMaterial3D:
                    var m: BaseMaterial3D = n.mesh.surface_get_material(s)
                    if m.albedo_texture: result["textured_surfaces"] += 1
    for c in n.get_children(): inspect(c,result)
func run_probe() -> void:
    for path in DirAccess.get_files_at("res://assets"):
        if not path.ends_with(".glb"): continue
        var packed = load("res://assets/"+path)
        var r := {"loaded": packed != null, "meshes":0,"triangles":0,"textured_surfaces":0,"skeletons":[],"animation_players":[]}
        if packed:
            var node: Node = packed.instantiate()
            root.add_child(node)
            inspect(node,r)
            root.remove_child(node)
            node.queue_free()
        report[path]=r
    var shader: Shader = load("res://circle_dither.gdshader")
    var material := ShaderMaterial.new()
    material.shader=shader
    var mi := MeshInstance3D.new()
    mi.mesh=BoxMesh.new()
    mi.material_override=material
    root.add_child(mi)
    var camera := Camera3D.new()
    camera.position=Vector3(0,0,4)
    root.add_child(camera)
    camera.current=true
    await process_frame
    await process_frame
    report["shader"]={"resource_loaded":shader != null,"default_uniforms":shader.get_shader_uniform_list()}
    var f:=FileAccess.open("res://runtime_verification.json",FileAccess.WRITE)
    f.store_string(JSON.stringify(report,"  "))
    print("ART_PROBE_FINISHED ",report.keys())
    quit()
