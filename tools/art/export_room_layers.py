"""Export aligned transparent layers from the v2 room blend.

Same camera as the sample. Character is never baked into the room shell.
Poses are rigid moves of the seated sculpt (no armature in the source file).
"""
import json
import math
import bpy
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLEND = Path(__file__).resolve().parent / "room_sample_v2.blend"
OUT = ROOT / "assets" / "room" / "layers"
OUT.mkdir(parents=True, exist_ok=True)

if bpy.data.filepath != str(BLEND):
    bpy.ops.wm.open_mainfile(filepath=str(BLEND))

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.render.threads_mode = "FIXED"
scene.render.threads = 8

CHAR = "50_Character_F01_Seated"
LIGHTS = "90_Lighting"
char_objects = list(bpy.data.collections[CHAR].objects)
matrices = {o.name: o.matrix_world.copy() for o in char_objects}
floors = [o for o in bpy.data.objects if o.name.startswith("Floor_")]


def set_render(names):
    for col in bpy.data.collections:
        col.hide_render = True
    bpy.data.collections[LIGHTS].hide_render = False
    for name in names:
        bpy.data.collections[name].hide_render = False
    for obj in bpy.data.objects:
        obj.hide_render = obj.hide_render


def _setup_depth_output():
    scene.view_layers[0].use_pass_z = True
    scene.use_nodes = True
    tree = scene.node_tree
    tree.nodes.clear()
    layers = tree.nodes.new("CompositorNodeRLayers")
    composite = tree.nodes.new("CompositorNodeComposite")
    tree.links.new(layers.outputs["Image"], composite.inputs["Image"])
    mapped = tree.nodes.new("CompositorNodeMapRange")
    mapped.inputs[1].default_value = 1.0
    mapped.inputs[2].default_value = 22.0
    mapped.inputs[3].default_value = 0.0
    mapped.inputs[4].default_value = 1.0
    tree.links.new(layers.outputs["Depth"], mapped.inputs[0])
    writer = tree.nodes.new("CompositorNodeOutputFile")
    writer.base_path = str(OUT)
    writer.format.file_format = "PNG"
    writer.format.color_mode = "BW"
    writer.format.color_depth = "16"
    tree.links.new(mapped.outputs[0], writer.inputs[0])
    return writer


DEPTH_OUT = _setup_depth_output()


def render(path):
    path = Path(path)
    scene.render.filepath = str(path)
    DEPTH_OUT.file_slots[0].path = path.stem + "_z_"
    bpy.ops.render.render(write_still=True)
    produced = OUT / ("%s_z_0001.png" % path.stem)
    target = OUT / ("%s_z.png" % path.stem)
    if produced.exists():
        produced.replace(target)
    print("WROTE", path)


def restore_character():
    for obj in char_objects:
        obj.matrix_world = matrices[obj.name].copy()


def tint_male(enabled):
    for obj in char_objects:
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type != "BSDF_PRINCIPLED":
                    continue
                key = "male_backup_" + mat.name
                if enabled:
                    if key not in scene:
                        scene[key] = list(node.inputs["Base Color"].default_value)
                    color = list(node.inputs["Base Color"].default_value)
                    if "Knit" in mat.name or "knit" in obj.name or "Knit" in obj.name:
                        node.inputs["Base Color"].default_value = (0.20, 0.38, 0.42, 1)
                    elif "Hair" in obj.name or "Bob" in obj.name or "fringe" in obj.name:
                        node.inputs["Base Color"].default_value = (0.12, 0.10, 0.09, 1)
                    elif "Trouser" in obj.name:
                        node.inputs["Base Color"].default_value = (0.18, 0.20, 0.24, 1)
                elif key in scene:
                    node.inputs["Base Color"].default_value = scene[key]


def visual_pivot():
    xs, ys, zs = [], [], []
    for obj in char_objects:
        for corner in obj.bound_box:
            world = matrices[obj.name] @ Vector(corner)
            xs.append(world.x)
            ys.append(world.y)
            zs.append(world.z)
    return Vector((
        (min(xs) + max(xs)) * 0.5,
        (min(ys) + max(ys)) * 0.5,
        (min(zs) + max(zs)) * 0.5,
    ))


PIVOT = visual_pivot()


def move_character(delta, rot_x=0.0, rot_z=0.0):
    restore_character()
    rot = Matrix.Rotation(rot_z, 4, "Z") @ Matrix.Rotation(rot_x, 4, "X")
    shift = PIVOT + Vector(delta)
    for obj in char_objects:
        local = matrices[obj.name].copy()
        local.translation -= PIVOT
        obj.matrix_world = Matrix.Translation(shift) @ rot @ local


NEAR_ARM = ["F01_near_forearm", "F01_near_hand", "F01_near_cuff", "F01_near_finger_0", "F01_near_finger_1", "F01_near_finger_2"]
FAR_ARM = ["F01_far_forearm", "F01_far_hand", "F01_far_cuff", "F01_far_finger_0", "F01_far_finger_1", "F01_far_finger_2"]


def _part_center(names):
    xs, ys, zs = [], [], []
    for name in names:
        obj = bpy.data.objects[name]
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            xs.append(world.x)
            ys.append(world.y)
            zs.append(world.z)
    return Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5))


def _spin(names, pivot, axis, angle):
    rot = Matrix.Rotation(angle, 4, axis)
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        obj.matrix_world = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ obj.matrix_world


def _aim(names, pivot, marker, target):
    """Rotate names around pivot so marker's direction lines up with target."""
    aim_a = marker - pivot
    aim_b = target - pivot
    axis = aim_a.cross(aim_b)
    if aim_a.length < 1e-4 or aim_b.length < 1e-4 or axis.length < 1e-5:
        return
    axis_n = axis.normalized()
    flat_a = aim_a - axis_n * aim_a.dot(axis_n)
    flat_b = aim_b - axis_n * aim_b.dot(axis_n)
    if flat_a.length < 1e-5 or flat_b.length < 1e-5:
        return
    flat_a.normalize()
    flat_b.normalize()
    angle = math.atan2(flat_a.cross(flat_b).dot(axis_n), flat_a.dot(flat_b))
    _spin(names, pivot, axis_n, angle)


def _spin_all(pivot, axis, angle):
    _spin([obj.name for obj in char_objects], pivot, axis, angle)


def _move_all(delta):
    shift = Matrix.Translation(Vector(delta))
    for obj in char_objects:
        obj.matrix_world = shift @ obj.matrix_world


def _lift_arms(amount):
    for names, cuff in ((NEAR_ARM, "F01_near_cuff"), (FAR_ARM, "F01_far_cuff")):
        _spin(names, _part_center([cuff]), "Y", amount)


NEAR_LACES = ["F01_Shoe_lace", "F01_Shoe_lace.001", "F01_Shoe_lace.002"]
FAR_LACES = ["F01_Shoe_lace.003", "F01_Shoe_lace.004", "F01_Shoe_lace.005"]
NEAR_LOWER = ["F01_near_trouser_calf", "F01_near_canvas_shoe", "F01_near_shoe_sole", "F01_near_sock", "F01_near_turned_hem"] + NEAR_LACES
FAR_LOWER = ["F01_far_trouser_calf", "F01_far_canvas_shoe", "F01_far_shoe_sole", "F01_far_sock", "F01_far_turned_hem"] + FAR_LACES
NEAR_LEG = ["F01_near_trouser_thigh"] + NEAR_LOWER
FAR_LEG = ["F01_far_trouser_thigh"] + FAR_LOWER


def _prop_in_char(obj):
    char_col = bpy.data.collections[CHAR]
    if obj.name not in char_col.objects:
        char_col.objects.link(obj)
    for col in list(obj.users_collection):
        if col != char_col:
            col.objects.unlink(obj)
    obj.hide_render = True
    return obj


def _ensure_book():
    if "Read_book" in bpy.data.objects:
        return bpy.data.objects["Read_book"]
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -8))
    book = bpy.context.active_object
    book.name = "Read_book"
    cover = bpy.data.materials.new("Book_cover")
    cover.use_nodes = True
    cover.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.72, 0.36, 0.30, 1)
    book.data.materials.append(cover)
    _prop_in_char(book)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -8))
    page = bpy.context.active_object
    page.name = "Read_page"
    paper = bpy.data.materials.new("Book_page")
    paper.use_nodes = True
    paper.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.96, 0.93, 0.86, 1)
    page.data.materials.append(paper)
    _prop_in_char(page)
    return book


def _ensure_stool():
    if "Read_stool" in bpy.data.objects:
        return bpy.data.objects["Read_stool"]
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, 0, -8))
    stool = bpy.context.active_object
    stool.name = "Read_stool"
    wood = bpy.data.materials.new("Stool_wood")
    wood.use_nodes = True
    wood.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.45, 0.30, 1)
    stool.data.materials.append(wood)
    return _prop_in_char(stool)


def _hide_prop(name, hidden):
    obj = bpy.data.objects.get(name)
    if obj is not None:
        obj.hide_render = hidden


def _head_names():
    keys = ("Head", "Hair", "Bob", "fringe", "Fringe", "Ear", "Eye", "lid", "Lid", "Eyebrow", "Cheek", "Nose", "smile", "Neck")
    return [obj.name for obj in char_objects if any(key in obj.name for key in keys)]


def _place_book():
    book = _ensure_book()
    page = bpy.data.objects.get("Read_page")
    hand = _part_center(["F01_near_hand", "F01_far_hand"])
    head = _part_center(["F01_Head_sculpt"])
    book.location = Vector((hand.x, hand.y + 0.02, min(hand.z, head.z - 0.34)))
    book.rotation_euler = (0.7, 0.05, 0.15)
    book.scale = (0.30, 0.22, 0.04)
    book.hide_render = False
    if page is not None:
        page.location = book.location + Vector((0.0, 0.0, 0.035))
        page.rotation_euler = book.rotation_euler
        page.scale = (0.30, 0.21, 0.012)
        page.hide_render = False


def _place_stool():
    stool = _ensure_stool()
    hip = _part_center(["F01_Trousers_seat"])
    stool.location = Vector((hip.x, hip.y, 0.46))
    stool.scale = (0.52, 0.46, 0.92)
    stool.rotation_euler = (0.0, 0.0, 0.0)
    stool.hide_render = False


def _style_male(enabled):
    for obj in char_objects:
        if "fringe" in obj.name or "Fringe" in obj.name or "Side_swept" in obj.name:
            obj.hide_render = enabled
        if obj.name.startswith("F01_Bob_lock"):
            obj.hide_render = False
    if not enabled:
        return
    cap = bpy.data.objects.get("F01_Hair_sculpted_cap")
    head = _part_center(["F01_Head_sculpt"])
    nose = _part_center(["F01_Nose"])
    back = head - nose
    if back.length < 1e-4:
        back = Vector((1.0, 0.0, 0.0))
    back = back.normalized()
    if cap is not None:
        cap.matrix_world = (
            Matrix.Translation(head + back * 0.05 + Vector((0.0, 0.0, 0.03)))
            @ Matrix.Diagonal(Vector((1.28, 1.28, 1.02, 1.0)))
            @ Matrix.Translation(-head)
            @ cap.matrix_world
        )
    # Pull the bob in toward the skull so it reads as a short cut in every pose.
    for obj in char_objects:
        if not obj.name.startswith("F01_Bob_lock"):
            continue
        obj.matrix_world = (
            Matrix.Translation(head)
            @ Matrix.Scale(0.58, 4)
            @ Matrix.Translation(-head)
            @ obj.matrix_world
        )


def _lay_legs_flat():
    """After the body is on its back, put both legs straight along -Y."""
    for full, lower, thigh, shoe in (
        (NEAR_LEG, NEAR_LOWER, "F01_near_trouser_thigh", "F01_near_canvas_shoe"),
        (FAR_LEG, FAR_LOWER, "F01_far_trouser_thigh", "F01_far_canvas_shoe"),
    ):
        seat = _part_center(["F01_Trousers_seat"])
        knee = _part_center([thigh])
        _aim(full, seat, knee, seat + Vector((knee.x - seat.x, -1.0, -0.02)))
        seat = _part_center(["F01_Trousers_seat"])
        knee = _part_center([thigh])
        ankle = _part_center([shoe])
        direction = knee - seat
        if direction.length < 1e-4:
            direction = Vector((0.0, -1.0, 0.0))
        _aim(lower, knee, ankle, knee + direction.normalized() * max(0.45, (ankle - knee).length))


def _rest_arms():
    hip = _part_center(["F01_Trousers_seat"])
    for arm, cuff, hand in (
        (NEAR_ARM, "F01_near_cuff", "F01_near_hand"),
        (FAR_ARM, "F01_far_cuff", "F01_far_hand"),
    ):
        shoulder = _part_center([cuff])
        palm = _part_center([hand])
        side = 0.38 if palm.x >= hip.x else -0.38
        _aim(arm, shoulder, palm, Vector((hip.x + side, hip.y - 0.12, hip.z + 0.02)))


def _reach(target):
    for arm, cuff, hand, side in (
        (NEAR_ARM, "F01_near_cuff", "F01_near_hand", -0.06),
        (FAR_ARM, "F01_far_cuff", "F01_far_hand", 0.06),
    ):
        shoulder = _part_center([cuff])
        palm = _part_center([hand])
        _aim(arm, shoulder, palm, target + Vector((side, 0.0, 0.0)))


def _stand_legs():
    for full, lower, thigh, shoe in (
        (NEAR_LEG, NEAR_LOWER, "F01_near_trouser_thigh", "F01_near_canvas_shoe"),
        (FAR_LEG, FAR_LOWER, "F01_far_trouser_thigh", "F01_far_canvas_shoe"),
    ):
        seat = _part_center(["F01_Trousers_seat"])
        knee = _part_center([thigh])
        _aim(full, seat, knee, seat + Vector((0.0, 0.02, -1.0)))
        knee = _part_center([thigh])
        ankle = _part_center([shoe])
        below = Vector((knee.x, knee.y, knee.z - 0.8))
        _aim(lower, knee, ankle, below)
        ankle = _part_center([shoe])
        knee = _part_center([thigh])
        if ankle.z > knee.z - 0.05:
            flip = (ankle - knee).cross(Vector((0.0, 0.0, -1.0)))
            if flip.length < 1e-4:
                flip = Vector((1.0, 0.0, 0.0))
            _spin(lower, knee, flip.normalized(), math.pi)


def _pose_report(label):
    hip = _part_center(["F01_Trousers_seat"])
    head = _part_center(["F01_Head_sculpt"])
    foot = _part_center(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
    hand = _part_center(["F01_near_hand", "F01_far_hand"])
    print(
        "POSE", label,
        "hip=(%.2f,%.2f,%.2f)" % (hip.x, hip.y, hip.z),
        "head=(%.2f,%.2f,%.2f)" % (head.x, head.y, head.z),
        "foot=(%.2f,%.2f,%.2f)" % (foot.x, foot.y, foot.z),
        "hand=(%.2f,%.2f,%.2f)" % (hand.x, hand.y, hand.z),
    )


def apply_pose(kind, extra):
    restore_character()
    _hide_prop("Read_book", True)
    _hide_prop("Read_page", True)
    _hide_prop("Read_stool", True)
    if kind == "bed":
        # Left-right is world Y. Turn so shoulders run across the bed, then
        # pitch onto the back with the head toward the pillow (+Y).
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "Z", math.pi / 2.0)
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "X", -math.pi / 2.0)
        _lay_legs_flat()
        _rest_arms()
        hip = _part_center(["F01_Trousers_seat"])
        _move_all(Vector((-1.70, 0.05, 1.02)) - hip)
    elif kind == "read":
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "Z", math.pi / 2.0)
        _reach(_part_center(["F01_Ribbed_collar"]) + Vector((0.0, -0.30, -0.42)))
        head = _part_center(["F01_Head_sculpt"])
        _spin(_head_names(), head, "X", -0.28)
        hip = _part_center(["F01_Trousers_seat"])
        _move_all(Vector((0.20, -1.05, 0.98)) - hip)
        _place_book()
        _place_stool()
    elif kind == "cat":
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "Z", math.pi / 2.0 + 0.35)
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "X", 0.95)
        foot = _part_center(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
        _move_all(Vector((-1.15, -1.22, 0.10)) - foot)
        _reach(Vector((-0.42, -1.78, 0.46)))
    elif kind == "door":
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "Z", -math.pi / 2.0)
        _stand_legs()
        _rest_arms()
        foot = _part_center(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
        _move_all(Vector((3.20, 1.45, 0.08)) - foot)
    if extra.length > 0.001:
        _move_all(extra)
        if kind == "read":
            _place_book()
            _place_stool()
    _pose_report(kind)


def render_character(path, delta, rot_x, male, rot_z=0.0):
    set_render([CHAR, "00_Structure"])
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = not obj.name.startswith("Floor_")
    for obj in floors:
        obj.is_shadow_catcher = True
        obj.hide_render = False
    tint_male(male)
    move_character(delta, rot_x, rot_z)
    render(path)
    restore_character()
    tint_male(False)
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = False
    for obj in floors:
        obj.is_shadow_catcher = False


print("MATERIALS")
seen = set()
for obj in char_objects:
    for slot in obj.material_slots:
        if slot.material and slot.material.name not in seen:
            seen.add(slot.material.name)
            print(" MAT", slot.material.name, "on", obj.name)

# Layout A poses. Pivot is the seated visual center, so identity stays on the chair.
# Z is low so the tipped sculpt sinks into the duvet instead of hovering.
BED_A = (Vector((-4.38, 0.44, -0.32)), 1.57, 0.0)
# In front of the shelf and left of the monitor, where the desk layer does not cover the body.
READ_A = (Vector((-2.50, 0.15, 0.0)), 0.0, 0.0)
DOOR_A = (Vector((0.32, 1.64, 0.0)), 0.0, 0.0)
# Layout B: bed moves to the open floor in front of the shelf; desk and chair move to the window.
BED_SHIFT = Vector((3.35, -0.75, 0.0))
DESK_SHIFT = Vector((-3.75, 0.17, 0.0))


def snapshot(names):
    saved = {}
    for name in names:
        for obj in bpy.data.collections[name].objects:
            saved[obj.name] = obj.matrix_world.copy()
    return saved


def shift_collection(name, delta, saved):
    for obj in bpy.data.collections[name].objects:
        obj.matrix_world = Matrix.Translation(delta) @ saved[obj.name]


def restore_snapshot(saved):
    for name, matrix in saved.items():
        bpy.data.objects[name].matrix_world = matrix


def tint_nodes(match, color):
    backups = []
    for mat in bpy.data.materials:
        if mat is None or not mat.use_nodes:
            continue
        if match not in mat.name:
            continue
        for node in mat.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            backups.append((node, list(node.inputs["Base Color"].default_value)))
            node.inputs["Base Color"].default_value = color
    return backups


def restore_nodes(backups):
    for node, color in backups:
        node.inputs["Base Color"].default_value = color


def render_prop(path, names):
    set_render(list(names) + ["00_Structure"])
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = not obj.name.startswith("Floor_")
    for obj in floors:
        obj.is_shadow_catcher = True
        obj.hide_render = False
    render(path)
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = False
    for obj in floors:
        obj.is_shadow_catcher = False


def tint_bed():
    return tint_nodes("07_Clay cotton", (0.36, 0.55, 0.50, 1))


def tint_shelf():
    return tint_nodes("04_Pale endgrain", (0.42, 0.26, 0.14, 1))


def tint_desk():
    return tint_nodes("09_Ink green", (0.12, 0.16, 0.22, 1))


import sys
CHAR_ONLY = "--characters" in sys.argv


def _link_only(obj, col):
    if obj.name not in col.objects:
        col.objects.link(obj)
    for other in list(obj.users_collection):
        if other != col:
            other.objects.unlink(obj)


def _clay(name, color):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = color
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
    return mat


def ensure_cat():
    if "Cat_body" in bpy.data.objects:
        return
    col = bpy.data.collections.new("80_Cat")
    bpy.context.scene.collection.children.link(col)
    fur = _clay("Cat_fur", (0.86, 0.55, 0.32, 1))
    dark = _clay("Cat_dark", (0.22, 0.14, 0.10, 1))
    cream = _clay("Cat_cream", (0.96, 0.90, 0.82, 1))

    def add(kind, name, loc, scale, mat, rot=(0.0, 0.0, 0.0)):
        if kind == "sphere":
            bpy.ops.mesh.primitive_uv_sphere_add(segments=28, ring_count=14, radius=1, location=loc)
        elif kind == "cube":
            bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
        else:
            bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=1, depth=1, location=loc)
        obj = bpy.context.active_object
        obj.name = name
        obj.scale = Vector(scale)
        obj.rotation_euler = rot
        obj.data.materials.append(mat)
        _link_only(obj, col)
        return obj

    # In front of the bed's foot, on the camera side of the room.
    add("sphere", "Cat_body", (-0.28, -1.92, 0.32), (0.46, 0.24, 0.22), fur)
    add("sphere", "Cat_chest", (-0.48, -1.90, 0.30), (0.16, 0.16, 0.12), cream)
    add("sphere", "Cat_head", (-0.62, -1.90, 0.48), (0.20, 0.18, 0.17), fur)
    add("cone", "Cat_ear", (-0.70, -2.02, 0.66), (0.07, 0.06, 0.12), dark)
    add("cone", "Cat_ear_b", (-0.70, -1.78, 0.66), (0.07, 0.06, 0.12), dark)
    add("sphere", "Cat_tail", (0.16, -1.86, 0.48), (0.07, 0.07, 0.22), fur, (0.4, 0.2, 0.4))
    add("sphere", "Cat_tail_tip", (0.22, -1.78, 0.66), (0.07, 0.07, 0.07), dark)
    add("sphere", "Cat_eye", (-0.78, -1.98, 0.52), (0.035, 0.03, 0.04), dark)
    add("sphere", "Cat_eye_b", (-0.78, -1.82, 0.52), (0.035, 0.03, 0.04), dark)
    add("sphere", "Cat_nose", (-0.80, -1.90, 0.44), (0.03, 0.03, 0.02), dark)
    add("cube", "Cat_rug", (-0.22, -1.90, 0.025), (1.15, 0.72, 0.04), cream)


if not CHAR_ONLY:
    set_render(["00_Structure", "60_Decor", "70_ExitDoor"])
    render(OUT / "shell.png")
    render_prop(OUT / "bed.png", ["10_Bed"])
    bed_tint = tint_bed()
    render_prop(OUT / "bed_l2.png", ["10_Bed"])
    restore_nodes(bed_tint)
    render_prop(OUT / "shelf.png", ["40_Bookcase"])
    shelf_tint = tint_shelf()
    render_prop(OUT / "shelf_l2.png", ["40_Bookcase"])
    restore_nodes(shelf_tint)
    render_prop(OUT / "chair.png", ["30_Chair"])
    render_prop(OUT / "desk_front.png", ["20_Desk"])
    desk_tint = tint_desk()
    render_prop(OUT / "desk_l2.png", ["20_Desk"])
    restore_nodes(desk_tint)

def render_posed(path, kind, male, extra):
    set_render([CHAR, "00_Structure"])
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = not obj.name.startswith("Floor_")
    for obj in floors:
        obj.is_shadow_catcher = True
        obj.hide_render = False
    tint_male(male)
    apply_pose(kind, extra)
    if male:
        _style_male(True)
    render(path)
    restore_character()
    _style_male(False)
    tint_male(False)
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = False
    for obj in floors:
        obj.is_shadow_catcher = False


def _column_bbox(names):
    xs, ys, zs = [], [], []
    for name in names:
        col = bpy.data.collections.get(name)
        if col is None:
            continue
        for obj in col.objects:
            if obj.name.startswith("ANCHOR"):
                continue
            for corner in obj.bound_box:
                world = obj.matrix_world @ Vector(corner)
                xs.append(world.x)
                ys.append(world.y)
                zs.append(world.z)
    return (min(xs), max(xs), min(ys), max(ys), min(zs), max(zs))


def add_upgrade_meshes():
    bed = bpy.data.collections["10_Bed"]
    if "Bed_footboard" not in bpy.data.objects:
        bpy.ops.mesh.primitive_cube_add(size=1, location=(-1.70, -1.64, 1.02))
        board = bpy.context.active_object
        board.name = "Bed_footboard"
        board.scale = (1.74, 0.08, 0.78)
        board.data.materials.append(_clay("Bed_foot_wood", (0.55, 0.36, 0.22, 1)))
        _link_only(board, bed)
        duvet = bpy.data.objects.get("Duvet_clay_cotton")
        if duvet is not None:
            duvet.scale = duvet.scale * Vector((1.0, 1.04, 1.12))
    shelf = bpy.data.collections["40_Bookcase"]
    if "Book_upgrade_extra" not in bpy.data.objects:
        tones = ((0.72, 0.36, 0.30, 1), (0.32, 0.48, 0.44, 1), (0.20, 0.28, 0.36, 1), (0.62, 0.48, 0.28, 1))
        for index, tone in enumerate(tones):
            bpy.ops.mesh.primitive_cube_add(size=1, location=(-0.48 + index * 0.28, 2.02, 2.24))
            book = bpy.context.active_object
            book.name = "Book_upgrade_extra" if index == 0 else "Book_upgrade_extra.%03d" % index
            book.scale = (0.11, 0.28, 0.40)
            book.data.materials.append(_clay("Upgrade_book_%d" % index, tone))
            _link_only(book, shelf)
    desk_up = bpy.data.collections.get("21_DeskUpgrade")
    if desk_up is not None:
        minx, _maxx, miny, _maxy, _minz, _maxz = _column_bbox(["20_Desk"])
        base = Vector((minx + 0.15, miny - 0.20, 0.58))
        offsets = {
            "Upgrade_pedestal": Vector((0.0, 0.0, 0.0)),
            "Upgrade_grounded_plinth": Vector((0.0, 0.0, -0.54)),
            "Upgrade_drawer_face": Vector((0.0, -0.32, 0.24)),
            "Upgrade_drawer_handle": Vector((0.0, -0.38, 0.24)),
            "Upgrade_drawer_face.001": Vector((0.0, -0.32, -0.04)),
            "Upgrade_drawer_handle.001": Vector((0.0, -0.38, -0.04)),
            "Upgrade_drawer_face.002": Vector((0.0, -0.32, -0.32)),
            "Upgrade_drawer_handle.002": Vector((0.0, -0.38, -0.32)),
        }
        for obj in desk_up.objects:
            off = offsets.get(obj.name, Vector((0.0, 0.0, 0.0)))
            rot = Matrix.Rotation(math.pi / 2.0, 4, "Z") if "drawer" in obj.name else Matrix.Identity(4)
            obj.matrix_world = Matrix.Translation(base + off) @ rot


PREVIEW = "--preview" in sys.argv
if PREVIEW:
    scene.cycles.samples = 8


def _screen_rect(objects, pad):
    from bpy_extras.object_utils import world_to_camera_view
    xs, ys = [], []
    resx = scene.render.resolution_x
    resy = scene.render.resolution_y
    for obj in objects:
        for corner in obj.bound_box:
            co = world_to_camera_view(scene, scene.camera, obj.matrix_world @ Vector(corner))
            xs.append(co.x * resx)
            ys.append((1.0 - co.y) * resy)
    if not xs:
        return None
    left = max(0.0, min(xs) - pad)
    top = max(0.0, min(ys) - pad)
    right = min(float(resx), max(xs) + pad)
    bottom = min(float(resy), max(ys) + pad)
    return [int(left), int(top), int(max(80, right - left)), int(max(64, bottom - top))]


def _store_cat_rect():
    col = bpy.data.collections.get("80_Cat")
    if col is None:
        return
    rect = _screen_rect(list(col.objects), 40)
    if rect is None:
        return
    path = ROOT / "assets" / "room" / "hotspot_anchors.json"
    data = json.loads(path.read_text())
    data.setdefault("rects", {})["cat"] = rect
    data.setdefault("rects_b", {})["cat"] = rect
    path.write_text(json.dumps(data, indent=2) + "\n")
    print("CAT_RECT", rect)


if "--door" in sys.argv:
    scene.cycles.samples = 12
    render_posed(OUT / "char_f_door.png", "door", False, Vector((0, 0, 0)))
    render_posed(OUT / "char_m_door.png", "door", True, Vector((0, 0, 0)))
    print("DOOR_DONE")
    raise SystemExit(0)

if "--poses" in sys.argv:
    scene.cycles.samples = 12
    render_posed(OUT / "char_f_read.png", "read", False, Vector((0, 0, 0)))
    render_posed(OUT / "char_m_read.png", "read", True, Vector((0, 0, 0)))
    print("POSES_DONE")
    raise SystemExit(0)

ensure_cat()
_store_cat_rect()
render_prop(OUT / "cat.png", ["80_Cat"])
add_upgrade_meshes()
render_prop(OUT / "bed_l2.png", ["10_Bed"])
render_prop(OUT / "shelf_l2.png", ["40_Bookcase"])
render_prop(OUT / "desk_l2.png", ["20_Desk", "21_DeskUpgrade"])

if PREVIEW:
    render_posed(OUT / "char_f_bed.png", "bed", False, Vector((0, 0, 0)))
    render_posed(OUT / "char_m_sit.png", "sit", True, Vector((0, 0, 0)))
    render_posed(OUT / "char_f_read.png", "read", False, Vector((0, 0, 0)))
    render_posed(OUT / "char_f_cat.png", "cat", False, Vector((0, 0, 0)))
    print("PREVIEW_DONE")
    raise SystemExit(0)

render_posed(OUT / "char_f_sit.png", "sit", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_sit.png", "sit", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_bed.png", "bed", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_bed.png", "bed", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_read.png", "read", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_read.png", "read", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_door.png", "door", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_door.png", "door", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_cat.png", "cat", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_cat.png", "cat", True, Vector((0, 0, 0)))

saved = snapshot(["10_Bed", "20_Desk", "30_Chair"])
shift_collection("10_Bed", BED_SHIFT, saved)
shift_collection("20_Desk", DESK_SHIFT, saved)
shift_collection("30_Chair", DESK_SHIFT, saved)
if not CHAR_ONLY:
    render_prop(OUT / "bed_b.png", ["10_Bed"])
    bed_tint = tint_bed()
    render_prop(OUT / "bed_b_l2.png", ["10_Bed"])
    restore_nodes(bed_tint)
    render_prop(OUT / "chair_b.png", ["30_Chair"])
    render_prop(OUT / "desk_b.png", ["20_Desk"])
    desk_tint = tint_desk()
    render_prop(OUT / "desk_b_l2.png", ["20_Desk"])
    restore_nodes(desk_tint)
if CHAR_ONLY:
    render_prop(OUT / "bed_b_l2.png", ["10_Bed"])
    upgrade = bpy.data.collections.get("21_DeskUpgrade")
    moved = {}
    if upgrade is not None:
        for obj in upgrade.objects:
            moved[obj.name] = obj.matrix_world.copy()
            obj.matrix_world = Matrix.Translation(DESK_SHIFT) @ obj.matrix_world
    render_prop(OUT / "desk_b_l2.png", ["20_Desk", "21_DeskUpgrade"])
    for name, matrix in moved.items():
        bpy.data.objects[name].matrix_world = matrix
render_posed(OUT / "char_f_sit_b.png", "sit", False, DESK_SHIFT)
render_posed(OUT / "char_m_sit_b.png", "sit", True, DESK_SHIFT)
render_posed(OUT / "char_f_bed_b.png", "bed", False, BED_SHIFT)
render_posed(OUT / "char_m_bed_b.png", "bed", True, BED_SHIFT)
restore_snapshot(saved)
print("DONE")
