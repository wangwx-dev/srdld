"""Export aligned transparent layers from the v2 room blend.

Same camera as the sample. Character is never baked into the room shell.
Poses are rigid moves of the seated sculpt (no armature in the source file).
"""
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
        obj = bpy.data.objects[name]
        obj.matrix_world = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ obj.matrix_world


def _spin_all(pivot, axis, angle):
    _spin([obj.name for obj in char_objects], pivot, axis, angle)


def _move_all(delta):
    shift = Matrix.Translation(Vector(delta))
    for obj in char_objects:
        obj.matrix_world = shift @ obj.matrix_world


def _lift_arms(amount):
    for names, cuff in ((NEAR_ARM, "F01_near_cuff"), (FAR_ARM, "F01_far_cuff")):
        _spin(names, _part_center([cuff]), "Y", amount)


def apply_pose(kind, extra):
    """Pose independent parts. Sit stays the sculpt. Bed lays the body on the mattress and rests the arms. Read turns toward the shelf and lifts the hands."""
    restore_character()
    if kind == "bed":
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "X", -1.5708)
        _lift_arms(0.45)
        hip = _part_center(["F01_Trousers_seat"])
        _move_all(Vector((-1.70, -0.05, 0.84)) - hip)
    elif kind == "read":
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "Z", 1.5708)
        _lift_arms(-1.1)
        foot = _part_center(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
        _move_all(Vector((-0.35, 0.72, 0.12)) - foot)
    elif kind == "door":
        hip = _part_center(["F01_Trousers_seat"])
        _spin_all(hip, "Z", 1.15)
        foot = _part_center(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
        _move_all(Vector((2.75, 1.45, 0.12)) - foot)
    if extra.length > 0.001:
        _move_all(extra)


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
    render(path)
    restore_character()
    tint_male(False)
    for obj in bpy.data.collections["00_Structure"].objects:
        obj.hide_render = False
    for obj in floors:
        obj.is_shadow_catcher = False


render_posed(OUT / "char_f_sit.png", "sit", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_sit.png", "sit", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_bed.png", "bed", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_bed.png", "bed", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_read.png", "read", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_read.png", "read", True, Vector((0, 0, 0)))
render_posed(OUT / "char_f_door.png", "door", False, Vector((0, 0, 0)))
render_posed(OUT / "char_m_door.png", "door", True, Vector((0, 0, 0)))

saved = snapshot(["10_Bed", "20_Desk", "30_Chair"])
shift_collection("10_Bed", BED_SHIFT, saved)
shift_collection("20_Desk", DESK_SHIFT, saved)
shift_collection("30_Chair", DESK_SHIFT, saved)
render_prop(OUT / "bed_b.png", ["10_Bed"])
bed_tint = tint_bed()
render_prop(OUT / "bed_b_l2.png", ["10_Bed"])
restore_nodes(bed_tint)
render_prop(OUT / "chair_b.png", ["30_Chair"])
render_prop(OUT / "desk_b.png", ["20_Desk"])
desk_tint = tint_desk()
render_prop(OUT / "desk_b_l2.png", ["20_Desk"])
restore_nodes(desk_tint)
render_posed(OUT / "char_f_sit_b.png", "sit", False, DESK_SHIFT)
render_posed(OUT / "char_m_sit_b.png", "sit", True, DESK_SHIFT)
render_posed(OUT / "char_f_bed_b.png", "bed", False, BED_SHIFT)
render_posed(OUT / "char_m_bed_b.png", "bed", True, BED_SHIFT)
restore_snapshot(saved)
print("DONE")
