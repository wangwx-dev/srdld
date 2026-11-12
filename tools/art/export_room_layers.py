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


def render(path):
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)
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

render_character(OUT / "char_f_bed.png", BED_A[0], BED_A[1], False, BED_A[2])
render_character(OUT / "char_m_bed.png", BED_A[0], BED_A[1], True, BED_A[2])
render_character(OUT / "char_f_read.png", READ_A[0], READ_A[1], False, READ_A[2])
render_character(OUT / "char_m_read.png", READ_A[0], READ_A[1], True, READ_A[2])
render_character(OUT / "char_f_door.png", DOOR_A[0], DOOR_A[1], False, DOOR_A[2])
render_character(OUT / "char_m_door.png", DOOR_A[0], DOOR_A[1], True, DOOR_A[2])

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
render_character(OUT / "char_f_sit_b.png", DESK_SHIFT, 0.0, False)
render_character(OUT / "char_m_sit_b.png", DESK_SHIFT, 0.0, True)
render_character(OUT / "char_f_bed_b.png", BED_A[0] + BED_SHIFT, BED_A[1], False, BED_A[2])
render_character(OUT / "char_m_bed_b.png", BED_A[0] + BED_SHIFT, BED_A[1], True, BED_A[2])
restore_snapshot(saved)
print("DONE")
