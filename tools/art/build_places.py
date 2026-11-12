"""Designed dioramas for the city and each outing.

Same warm plaster, sage, and wood as the room. Forms are facades, frames,
roofs, and furniture, not unlabeled boxes. Cycles so the light matches the room.
"""
import math
import os
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

CHAR_BLEND = Path(__file__).resolve().parent / "room_sample_v2.blend"
NEAR_ARM = ["F01_near_forearm", "F01_near_hand", "F01_near_cuff", "F01_near_finger_0", "F01_near_finger_1", "F01_near_finger_2"]
FAR_ARM = ["F01_far_forearm", "F01_far_hand", "F01_far_cuff", "F01_far_finger_0", "F01_far_finger_1", "F01_far_finger_2"]
NEAR_LACES = ["F01_Shoe_lace", "F01_Shoe_lace.001", "F01_Shoe_lace.002"]
FAR_LACES = ["F01_Shoe_lace.003", "F01_Shoe_lace.004", "F01_Shoe_lace.005"]
NEAR_LOWER = ["F01_near_trouser_calf", "F01_near_canvas_shoe", "F01_near_shoe_sole", "F01_near_sock", "F01_near_turned_hem"] + NEAR_LACES
FAR_LOWER = ["F01_far_trouser_calf", "F01_far_canvas_shoe", "F01_far_shoe_sole", "F01_far_sock", "F01_far_turned_hem"] + FAR_LACES
NEAR_LEG = ["F01_near_trouser_thigh"] + NEAR_LOWER
FAR_LEG = ["F01_far_trouser_thigh"] + FAR_LOWER

OUT = Path(__file__).resolve().parents[2] / "assets" / "places"
FONT_PATH = Path(__file__).resolve().parents[2] / "assets" / "fonts" / "SourceHanSansCN-Regular.otf"
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 16 if os.environ.get("PLACE_PREVIEW") else 36
scene.cycles.use_denoising = True
scene.render.resolution_x = 1440
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.view_settings.view_transform = "Standard"
scene.view_settings.look = "Medium High Contrast"

scene.world = bpy.data.worlds.new("PlaceSky")
scene.world.use_nodes = True

cam_data = bpy.data.cameras.new("PlaceCam")
cam_data.lens = 38
cam = bpy.data.objects.new("PlaceCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 2.6
sun_data.angle = math.radians(6)
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(52), math.radians(8), math.radians(28))

fill_data = bpy.data.lights.new("Fill", "AREA")
fill_data.energy = 80
fill_data.size = 4
fill_data.color = (1.0, 0.93, 0.82)
fill = bpy.data.objects.new("Fill", fill_data)
scene.collection.objects.link(fill)
fill.location = (-2.2, -3.2, 2.6)
fill.rotation_euler = (math.radians(70), 0, math.radians(-20))

FONT = bpy.data.fonts.load(str(FONT_PATH))
made = []


def sky(color, strength=0.45):
    node = scene.world.node_tree.nodes["Background"]
    node.inputs["Color"].default_value = color
    node.inputs["Strength"].default_value = strength


def look(location, target, lens=36):
    cam.location = Vector(location)
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


def mat(name, color, rough=0.62):
    item = bpy.data.materials.new(name)
    item.use_nodes = True
    node = item.node_tree.nodes["Principled BSDF"]
    node.inputs["Base Color"].default_value = color
    node.inputs["Roughness"].default_value = rough
    return item


PLASTER = mat("Plaster", (0.90, 0.86, 0.78, 1), 0.72)
SAGE = mat("Sage", (0.50, 0.66, 0.60, 1), 0.7)
SAGE_D = mat("SageDark", (0.28, 0.42, 0.38, 1), 0.66)
WOOD = mat("Wood", (0.62, 0.45, 0.28, 1), 0.58)
WOOD_D = mat("WoodDark", (0.36, 0.24, 0.15, 1), 0.5)
CREAM = mat("Cream", (0.96, 0.93, 0.86, 1), 0.55)
INK = mat("Ink", (0.18, 0.20, 0.22, 1), 0.45)
GRASS = mat("Grass", (0.55, 0.68, 0.46, 1), 0.8)
GRASS_D = mat("GrassDark", (0.40, 0.52, 0.34, 1), 0.82)
PATH = mat("Path", (0.78, 0.70, 0.56, 1), 0.75)
STONE = mat("Stone", (0.72, 0.70, 0.66, 1), 0.7)
SCREEN = mat("Screen", (0.78, 0.86, 0.90, 1), 0.18)
GOLD = mat("Gold", (0.86, 0.67, 0.32, 1), 0.35)
CLAY = mat("Clay", (0.86, 0.58, 0.50, 1), 0.6)
CORAL = mat("Coral", (0.82, 0.48, 0.42, 1), 0.55)
SEAT = mat("Seat", (0.33, 0.38, 0.40, 1), 0.48)


def add(kind, name, loc, scale, material, rot=(0, 0, 0)):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.5, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=0.5, depth=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(scale)
    obj.rotation_euler = rot
    if obj.data.materials:
        obj.data.materials[0] = material
    else:
        obj.data.materials.append(material)
    made.append(obj)
    return obj


def clear():
    for obj in list(made):
        bpy.data.objects.remove(obj, do_unlink=True)
    made.clear()


def label(name, text, loc, size, material, rot=(math.radians(90), 0, 0)):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.font = FONT
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = 0.012
    curve.materials.append(material)
    obj = bpy.data.objects.new(name, curve)
    obj.location = Vector(loc)
    obj.rotation_euler = rot
    scene.collection.objects.link(obj)
    made.append(obj)
    return obj


def window(name, x, y, z, w=0.72, h=0.86):
    add("cube", name + "_frame", (x, y, z), (w, 0.06, h), WOOD_D)
    add("cube", name + "_glass", (x, y - 0.02, z), (w - 0.12, 0.03, h - 0.12), SCREEN)
    add("cube", name + "_mullion", (x, y - 0.035, z), (0.035, 0.02, h - 0.16), WOOD)
    add("cube", name + "_rail", (x, y - 0.035, z), (w - 0.16, 0.02, 0.035), WOOD)
    add("cube", name + "_sill", (x, y - 0.04, z - h * 0.5), (w + 0.08, 0.1, 0.05), WOOD)


def door(name, x, y, z, w=0.62, h=1.35):
    add("cube", name + "_frame", (x, y, z), (w + 0.12, 0.08, h + 0.08), WOOD_D)
    add("cube", name + "_leaf", (x, y - 0.02, z - 0.02), (w, 0.05, h), SAGE)
    add("cube", name + "_panel", (x, y - 0.05, z + 0.12), (w - 0.16, 0.02, h * 0.42), CREAM)
    add("cyl", name + "_knob", (x + w * 0.28, y - 0.08, z), (0.05, 0.05, 0.04), GOLD, (math.radians(90), 0, 0))
    add("cube", name + "_step", (x, y - 0.28, 0.04), (w + 0.3, 0.42, 0.08), STONE)


def sign_board(name, text, x, y, z, w=1.15, h=0.32):
    add("cube", name + "_board", (x, y, z), (w, 0.06, h), WOOD_D)
    add("cube", name + "_face", (x, y - 0.02, z), (w - 0.08, 0.03, h - 0.08), CREAM)
    label(name + "_word", text, (x, y - 0.07, z), 0.2, INK, (math.radians(72), 0, math.radians(14)))


def tree(name, x, y, scale=1.0):
    add("cyl", name + "_trunk", (x, y, 0.55 * scale), (0.16 * scale, 0.16 * scale, 1.1 * scale), WOOD_D)
    add("sphere", name + "_leaf", (x, y, 1.45 * scale), (1.15 * scale, 1.05 * scale, 0.72 * scale), SAGE_D)
    add("sphere", name + "_leaf_b", (x + 0.28 * scale, y - 0.12 * scale, 1.15 * scale), (0.72 * scale, 0.68 * scale, 0.48 * scale), SAGE)
    add("sphere", name + "_leaf_c", (x - 0.22 * scale, y + 0.08 * scale, 1.7 * scale), (0.62 * scale, 0.58 * scale, 0.4 * scale), SAGE_D)


def flowerbed(name, x, y):
    add("cube", name + "_bed", (x, y, 0.06), (0.9, 0.55, 0.1), GRASS_D)
    add("sphere", name + "_a", (x - 0.18, y, 0.16), (0.22, 0.18, 0.14), CORAL)
    add("sphere", name + "_b", (x + 0.16, y + 0.08, 0.15), (0.18, 0.16, 0.12), GOLD)
    add("sphere", name + "_c", (x + 0.02, y - 0.1, 0.14), (0.16, 0.14, 0.1), CLAY)


def bench(name, x, y, z=0.0):
    for index in range(4):
        add("cube", "%s_slat_%d" % (name, index), (x, y - 0.12 + index * 0.08, z + 0.42), (1.35, 0.06, 0.04), WOOD)
    add("cube", name + "_back", (x, y + 0.22, z + 0.68), (1.35, 0.05, 0.42), WOOD)
    add("cube", name + "_leg", (x - 0.5, y, z + 0.2), (0.08, 0.36, 0.4), WOOD_D)
    add("cube", name + "_leg_b", (x + 0.5, y, z + 0.2), (0.08, 0.36, 0.4), WOOD_D)


def _player_names():
    col = bpy.data.collections.get("50_Character_F01_Seated")
    if col is None:
        return []
    return [obj.name for obj in col.objects]


PLAYER_REST = {}


def _ensure_player():
    if "F01_Trousers_seat" not in bpy.data.objects:
        bpy.ops.wm.append(
            directory=str(CHAR_BLEND) + "/Collection/",
            filename="50_Character_F01_Seated",
        )
    ok = "F01_Trousers_seat" in bpy.data.objects
    if ok and not PLAYER_REST:
        for name in _player_names():
            PLAYER_REST[name] = bpy.data.objects[name].matrix_world.copy()
    print("PLAYER", len(_player_names()), "ok" if ok else "MISSING")
    return ok


def _restore_player():
    for name, matrix in PLAYER_REST.items():
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        obj.matrix_world = matrix.copy()
        obj.hide_render = False


def hide_player():
    for name in _player_names():
        bpy.data.objects[name].hide_render = True


def _pcenter(names):
    xs, ys, zs = [], [], []
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            xs.append(world.x)
            ys.append(world.y)
            zs.append(world.z)
    if not xs:
        return Vector((0.0, 0.0, 0.0))
    return Vector(((min(xs) + max(xs)) * 0.5, (min(ys) + max(ys)) * 0.5, (min(zs) + max(zs)) * 0.5))


def _spin(names, pivot, axis, angle):
    rot = Matrix.Rotation(angle, 4, axis)
    for name in names:
        obj = bpy.data.objects.get(name)
        if obj is None:
            continue
        obj.matrix_world = Matrix.Translation(pivot) @ rot @ Matrix.Translation(-pivot) @ obj.matrix_world


def _move_player(delta):
    shift = Matrix.Translation(Vector(delta))
    for name in _player_names():
        obj = bpy.data.objects[name]
        obj.matrix_world = shift @ obj.matrix_world
        obj.hide_render = False


def _aim(names, pivot, marker, target):
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


def _flex(names, pivot, marker, target_dir, lateral):
    lat = lateral.normalized()
    current = marker - pivot
    cur = current - lat * current.dot(lat)
    tgt = Vector(target_dir)
    tgt = tgt - lat * tgt.dot(lat)
    if cur.length < 1e-5 or tgt.length < 1e-5:
        return
    cur.normalize()
    tgt.normalize()
    angle = math.atan2(cur.cross(tgt).dot(lat), cur.dot(tgt))
    _spin(names, pivot, lat, angle)


def _bone_end(name, origin):
    obj = bpy.data.objects[name]
    corners = [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    center = sum(corners, Vector()) / len(corners)
    direction = center - origin
    if direction.length < 1e-5:
        return center
    direction = direction.normalized()
    return max(corners, key=lambda point: (point - origin).dot(direction))


def _stand_player():
    hip = _pcenter(["F01_Trousers_seat"])
    foot = _pcenter(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
    forward = Vector((foot.x - hip.x, foot.y - hip.y, 0.0))
    if forward.length < 1e-4:
        forward = Vector((0.0, 1.0, 0.0))
    lateral = Vector((0.0, 0.0, 1.0)).cross(forward.normalized())
    down = Vector((0.0, 0.0, -1.0))
    for full, lower, thigh, shoe in (
        (NEAR_LEG, NEAR_LOWER, "F01_near_trouser_thigh", "F01_near_canvas_shoe"),
        (FAR_LEG, FAR_LOWER, "F01_far_trouser_thigh", "F01_far_canvas_shoe"),
    ):
        hip = _pcenter(["F01_Trousers_seat"])
        knee = _pcenter([thigh])
        _flex(full, hip, knee, down, lateral)
        joint = _bone_end(thigh, hip)
        ankle = _pcenter([shoe])
        _flex(lower, joint, ankle, down, lateral)


def seat_player(target, yaw):
    if not _ensure_player():
        return
    _restore_player()
    names = _player_names()
    hip = _pcenter(["F01_Trousers_seat"])
    _spin(names, hip, "Z", yaw)
    hip = _pcenter(["F01_Trousers_seat"])
    _move_player(Vector(target) - hip)


def stand_player(foot_target, yaw):
    if not _ensure_player():
        return
    _restore_player()
    names = _player_names()
    hip = _pcenter(["F01_Trousers_seat"])
    _spin(names, hip, "Z", yaw)
    _stand_player()
    foot = _pcenter(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
    _move_player(Vector(foot_target) - foot)


def _head_names():
    keys = ("Head", "Hair", "Bob", "fringe", "Fringe", "Ear", "Eye", "lid", "Lid", "Eyebrow", "Cheek", "Nose", "smile", "Neck")
    return [name for name in _player_names() if any(key in name for key in keys)]


def _reach(target):
    for arm, cuff, hand, side in (
        (NEAR_ARM, "F01_near_cuff", "F01_near_hand", -0.06),
        (FAR_ARM, "F01_far_cuff", "F01_far_hand", 0.06),
    ):
        shoulder = _pcenter([cuff])
        palm = _pcenter([hand])
        _aim(arm, shoulder, palm, Vector(target) + Vector((side, 0.0, 0.0)))


def _style_male():
    for name in _player_names():
        obj = bpy.data.objects[name]
        if "fringe" in name or "Fringe" in name or "Side_swept" in name:
            obj.hide_render = True
        for slot in obj.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            for node in mat.node_tree.nodes:
                if node.type != "BSDF_PRINCIPLED":
                    continue
                if "Knit" in mat.name or "knit" in name or "Knit" in name:
                    node.inputs["Base Color"].default_value = (0.20, 0.38, 0.42, 1)
                elif "Hair" in name or "Bob" in name or "fringe" in name:
                    node.inputs["Base Color"].default_value = (0.12, 0.10, 0.09, 1)
                elif "Trouser" in name:
                    node.inputs["Base Color"].default_value = (0.18, 0.20, 0.24, 1)
    cap = bpy.data.objects.get("F01_Hair_sculpted_cap")
    head = _pcenter(["F01_Head_sculpt"])
    nose = _pcenter(["F01_Nose"])
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
    for name in _player_names():
        if not name.startswith("F01_Bob_lock"):
            continue
        obj = bpy.data.objects[name]
        obj.matrix_world = (
            Matrix.Translation(head)
            @ Matrix.Scale(0.58, 4)
            @ Matrix.Translation(-head)
            @ obj.matrix_world
        )


def _finish_player():
    if os.environ.get("PLACE_GENDER", "f") == "m":
        _style_male()


def _hold_dumbbells():
    hip = _pcenter(["F01_Trousers_seat"])
    foot = _pcenter(["F01_near_canvas_shoe", "F01_far_canvas_shoe"])
    forward = Vector((foot.x - hip.x, foot.y - hip.y, 0.0))
    if forward.length < 1e-4:
        forward = Vector((0.0, -1.0, 0.0))
    forward.normalize()
    lateral = Vector((0.0, 0.0, 1.0)).cross(forward)
    if lateral.length < 1e-4:
        lateral = Vector((1.0, 0.0, 0.0))
    lateral.normalize()
    for arm, cuff, hand, side in (
        (NEAR_ARM, "F01_near_cuff", "F01_near_hand", 1.0),
        (FAR_ARM, "F01_far_cuff", "F01_far_hand", -1.0),
    ):
        shoulder = _pcenter([cuff])
        palm = _pcenter([hand])
        # Chest-height curl: hand stays on its own side and lifts in front of the shoulder.
        target = shoulder + forward * 0.22 + lateral * side * 0.08 + Vector((0.0, 0.0, 0.06))
        _flex(arm, shoulder, palm, target - shoulder, lateral)
        palm = _pcenter([hand])
        prefix = "curl_%s" % hand
        bar = palm
        add("cyl", prefix + "_bar", (bar.x, bar.y, bar.z), (0.08, 0.08, 0.36), WOOD_D, (0, math.radians(90), 0))
        add("cyl", prefix + "_a", (bar.x - 0.18, bar.y, bar.z), (0.18, 0.18, 0.07), INK, (0, math.radians(90), 0))
        add("cyl", prefix + "_b", (bar.x + 0.18, bar.y, bar.z), (0.18, 0.18, 0.07), INK, (0, math.radians(90), 0))


def _read_book():
    head = _pcenter(["F01_Head_sculpt"])
    _spin(_head_names(), head, "X", -0.32)
    hand = _pcenter(["F01_near_hand", "F01_far_hand"])
    book = Vector((hand.x, hand.y - 0.02, hand.z + 0.02))
    _reach(book)
    hand = _pcenter(["F01_near_hand", "F01_far_hand"])
    add("cube", "held_cover", (hand.x, hand.y, hand.z), (0.28, 0.20, 0.035), WOOD, (0.65, 0.05, 0.1))
    add("cube", "held_page", (hand.x, hand.y - 0.01, hand.z + 0.03), (0.24, 0.16, 0.012), CREAM, (0.65, 0.05, 0.1))


def facade(name, x, width, depth, height, wall, roof):
    add("cube", name + "_wall", (x, 0.15, height * 0.5), (width, depth, height), wall)
    add("cube", name + "_base", (x, 0.05, 0.12), (width + 0.08, depth + 0.12, 0.24), STONE)
    add("cube", name + "_roof", (x, 0.12, height + 0.08), (width + 0.28, depth + 0.35, 0.12), roof)
    add("cube", name + "_fascia", (x, -depth * 0.5 + 0.02, height + 0.02), (width + 0.32, 0.08, 0.1), WOOD_D)


def render(name):
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("WROTE", name)


def city():
    hide_player()
    sky((0.63, 0.76, 0.86, 1), 0.55)
    look((6.2, -8.6, 4.8), (0.4, 0.2, 1.15), 32)
    add("cube", "grass", (0.3, 0.6, -0.08), (14, 8, 0.1), GRASS)
    add("cube", "sidewalk", (0.3, -1.15, 0.02), (13.2, 1.7, 0.06), STONE)
    add("cube", "curb", (0.3, -2.05, 0.01), (13.2, 0.12, 0.1), WOOD_D)
    add("cube", "road", (0.3, -2.85, -0.02), (13.4, 1.55, 0.06), INK)
    add("cube", "lane", (0.3, -2.85, 0.02), (8.5, 0.06, 0.015), GOLD)
    for index in range(6):
        add("cube", "cross_%d" % index, (-1.4 + index * 0.32, -2.15, 0.025), (0.16, 0.7, 0.02), CREAM)
    specs = [
        (-4.6, 1.7, 2.2, SAGE, WOOD, "公园", True),
        (-2.2, 1.9, 2.7, INK, GOLD, "影院", False),
        (0.15, 1.7, 3.15, WOOD, WOOD_D, "图书馆", False),
        (2.5, 2.3, 2.45, PLASTER, CORAL, "商场", False),
        (5.0, 1.8, 2.35, SAGE, SAGE_D, "健身", False),
    ]
    for x, width, height, wall, roof, title, is_park in specs:
        facade(title, x, width, 1.35, height, wall, roof)
        if is_park:
            add("cube", "arch_l", (x - 0.42, -0.55, 1.15), (0.12, 0.12, 2.2), WOOD)
            add("cube", "arch_r", (x + 0.42, -0.55, 1.15), (0.12, 0.12, 2.2), WOOD)
            add("cube", "arch_top", (x, -0.55, 2.2), (1.05, 0.12, 0.12), WOOD)
            tree("park_a", x - 0.15, 0.85, 0.85)
            tree("park_b", x + 0.55, 1.15, 0.65)
            flowerbed("park_flowers", x + 0.7, -0.85)
        else:
            door(title + "_door", x, -0.52, 0.78)
            window(title + "_win", x, -0.62, height * 0.62, min(1.05, width * 0.55), 0.9)
        sign_board(title + "_sign", title, x, -0.78, height - 0.28, min(1.2, width * 0.7), 0.34)
    add("cyl", "gym_bar", (5.0, -0.78, 1.55), (0.9, 0.06, 0.06), INK, (0, math.radians(90), 0))
    add("cyl", "gym_plate_a", (4.55, -0.78, 1.55), (0.22, 0.22, 0.06), WOOD, (0, math.radians(90), 0))
    add("cyl", "gym_plate_b", (5.45, -0.78, 1.55), (0.22, 0.22, 0.06), WOOD, (0, math.radians(90), 0))
    for index, tone in enumerate((CORAL, SAGE, GOLD)):
        add("cube", "awning_%d" % index, (1.85 + index * 0.62, -0.72, 1.72), (0.55, 0.38, 0.06), tone, (math.radians(18), 0, 0))
    tree("street_tree", -3.5, -1.15, 0.55)
    tree("street_tree_b", 3.8, -1.25, 0.5)


def park():
    hide_player()
    sky((0.66, 0.80, 0.90, 1), 0.6)
    look((4.2, -5.2, 2.8), (0.1, 0.15, 0.7), 34)
    add("cube", "grass", (0, 0.2, -0.05), (9, 7, 0.1), GRASS)
    add("cube", "verge", (-2.3, 0.4, -0.02), (2.2, 4.5, 0.06), GRASS_D)
    add("cube", "path", (0.15, -0.1, 0.02), (1.25, 6.2, 0.05), PATH)
    add("cube", "path_edge", (-0.5, -0.1, 0.03), (0.08, 6.2, 0.04), STONE)
    add("cube", "path_edge_b", (0.8, -0.1, 0.03), (0.08, 6.2, 0.04), STONE)
    tree("t1", -2.3, 1.2, 1.05)
    tree("t2", 2.15, 0.9, 0.9)
    tree("t3", -1.9, -1.5, 0.75)
    tree("t4", 2.4, -1.35, 0.7)
    bench("seat", 1.25, 0.2)
    flowerbed("flowers", -1.15, 0.7)
    flowerbed("flowers_b", -1.4, -0.5)
    add("cyl", "lamp", (2.55, -1.45, 0.85), (0.07, 0.07, 1.7), INK)
    add("sphere", "lamp_head", (2.55, -1.45, 1.75), (0.32, 0.32, 0.2), GOLD)
    seat_player((1.15, 0.12, 0.50), math.pi / 2.0)
    _finish_player()


def cinema():
    hide_player()
    sky((0.05, 0.06, 0.07, 1), 0.15)
    look((0.15, -3.6, 1.7), (0.0, 1.5, 1.25), 30)
    add("cube", "floor", (0, 0.2, -0.04), (6.6, 6.2, 0.08), INK)
    add("cube", "back", (0, 2.55, 1.55), (6.4, 0.16, 3.1), INK)
    add("cube", "side_l", (-3.2, 0.0, 1.55), (0.16, 5.4, 3.1), INK)
    add("cube", "side_r", (3.2, 0.0, 1.55), (0.16, 5.4, 3.1), INK)
    add("cube", "screen_frame", (0, 2.35, 1.6), (4.3, 0.08, 2.15), WOOD_D)
    add("cube", "screen", (0, 2.28, 1.6), (3.9, 0.04, 1.85), SCREEN)
    add("cube", "pic", (-0.7, 2.24, 1.75), (1.35, 0.02, 0.85), CORAL)
    add("cube", "pic_b", (0.85, 2.23, 1.28), (1.2, 0.02, 0.4), SAGE)
    for row in range(5):
        y = 1.15 - row * 0.72
        z = 0.22 + row * 0.08
        for side, seats in ((-1, 3), (1, 3)):
            for seat in range(seats):
                x = side * (0.42 + seat * 0.58)
                prefix = "s_%d_%d_%d" % (row, side, seat)
                add("cube", prefix + "_pad", (x, y, z), (0.46, 0.42, 0.1), SEAT)
                add("cube", prefix + "_back", (x, y + 0.2, z + 0.32), (0.46, 0.06, 0.48), SEAT)
                add("cube", prefix + "_arm", (x - 0.24, y, z + 0.18), (0.05, 0.36, 0.08), WOOD_D)
                add("cube", prefix + "_arm_b", (x + 0.24, y, z + 0.18), (0.05, 0.36, 0.08), WOOD_D)
        add("cube", "step_%d" % row, (0, y, z - 0.12), (0.7, 0.5, 0.05), WOOD_D)
    seat_player((-1.0, -0.35, 0.52), -math.pi / 2.0)
    _finish_player()
    add("sphere", "sconce", (-2.9, 0.4, 1.7), (0.12, 0.08, 0.16), GOLD)
    add("sphere", "sconce_b", (2.9, 0.4, 1.7), (0.12, 0.08, 0.16), GOLD)


def gym():
    hide_player()
    sky((0.80, 0.84, 0.82, 1), 0.4)
    look((3.4, -4.4, 2.3), (0.1, 0.15, 0.85), 32)
    add("cube", "floor", (0, 0, -0.04), (7.4, 5.6, 0.08), CREAM)
    add("cube", "wall", (0, 2.2, 1.4), (7.2, 0.14, 2.8), SAGE)
    add("cube", "mirror", (-0.2, 2.1, 1.5), (2.8, 0.04, 1.35), SCREEN)
    add("cube", "mirror_frame", (-0.2, 2.12, 1.5), (3.0, 0.03, 1.5), WOOD_D)
    add("cube", "mat", (-1.85, 0.15, 0.03), (2.1, 1.45, 0.05), SAGE_D)
    add("cube", "mat_edge", (-1.85, 0.15, 0.055), (2.25, 1.6, 0.02), CREAM)
    # Dumbbells lie on the mat: handle along X, plates on the ends.
    add("cyl", "bell_handle", (-1.7, 0.25, 0.14), (0.07, 0.07, 0.36), WOOD, (0, math.radians(90), 0))
    add("cyl", "bell_a", (-1.9, 0.25, 0.14), (0.18, 0.18, 0.06), INK, (0, math.radians(90), 0))
    add("cyl", "bell_b", (-1.5, 0.25, 0.14), (0.18, 0.18, 0.06), INK, (0, math.radians(90), 0))
    add("cyl", "bell2_handle", (-1.55, -0.15, 0.12), (0.06, 0.06, 0.28), WOOD, (0, math.radians(90), 0))
    add("cyl", "bell2_a", (-1.72, -0.15, 0.12), (0.14, 0.14, 0.05), WOOD_D, (0, math.radians(90), 0))
    add("cyl", "bell2_b", (-1.38, -0.15, 0.12), (0.14, 0.14, 0.05), WOOD_D, (0, math.radians(90), 0))
    for post_x, post_y in ((0.95, -0.15), (2.25, -0.15), (0.95, 0.45), (2.25, 0.45)):
        add("cube", "post_%.0f_%.0f" % (post_x * 10, post_y * 10), (post_x, post_y, 0.75), (0.07, 0.07, 1.5), INK)
    add("cyl", "safety", (1.6, -0.15, 0.7), (0.05, 0.05, 1.4), INK, (0, math.radians(90), 0))
    add("cyl", "safety_b", (1.6, 0.45, 0.7), (0.05, 0.05, 1.4), INK, (0, math.radians(90), 0))
    add("cyl", "bar", (1.6, 0.15, 1.2), (0.07, 0.07, 1.9), WOOD_D, (0, math.radians(90), 0))
    add("cyl", "plate_l", (0.75, 0.15, 1.2), (0.36, 0.36, 0.08), CLAY, (0, math.radians(90), 0))
    add("cyl", "plate_r", (2.45, 0.15, 1.2), (0.36, 0.36, 0.08), CLAY, (0, math.radians(90), 0))
    add("cube", "bench_pad", (1.6, -1.45, 0.48), (1.2, 0.42, 0.08), SAGE)
    add("cube", "bench_leg", (1.15, -1.45, 0.22), (0.08, 0.32, 0.42), WOOD_D)
    add("cube", "bench_leg_b", (2.05, -1.45, 0.22), (0.08, 0.32, 0.42), WOOD_D)
    seat_player((1.6, -1.35, 0.58), math.pi / 2.0)
    _hold_dumbbells()
    _finish_player()


def mall():
    hide_player()
    sky((0.93, 0.89, 0.82, 1), 0.4)
    look((0.1, -4.8, 2.15), (0.0, 0.4, 0.95), 32)
    add("cube", "floor", (0, 0.1, -0.04), (8.8, 5.6, 0.08), PATH)
    add("cube", "back", (0, 2.15, 1.45), (8.4, 0.16, 2.9), PLASTER)
    shops = [(-2.6, CORAL, "吃的"), (0.0, SAGE, "日用"), (2.6, WOOD, "家具")]
    for index, (x, color, title) in enumerate(shops):
        add("cube", "bay_%d" % index, (x, 1.35, 1.2), (2.3, 0.12, 2.3), CREAM)
        window("shopwin_%d" % index, x, 1.22, 1.45, 1.35, 0.95)
        add("cube", "counter_%d" % index, (x, 0.35, 0.48), (1.7, 0.55, 0.9), WOOD)
        add("cube", "counter_top_%d" % index, (x, 0.35, 0.95), (1.8, 0.62, 0.06), CREAM)
        add("cube", "awning_%d" % index, (x, 0.55, 2.05), (2.15, 0.7, 0.06), color, (math.radians(16), 0, 0))
        sign_board("shop_%d" % index, title, x, 0.95, 2.28, 1.15, 0.28)
    add("cube", "snack_box", (-2.9, 0.4, 1.12), (0.28, 0.22, 0.2), CORAL)
    add("cube", "snack_bag", (-2.45, 0.35, 1.18), (0.16, 0.12, 0.32), GOLD)
    add("cyl", "bottle", (-0.35, 0.4, 1.22), (0.08, 0.08, 0.36), SAGE)
    add("cyl", "bottle_b", (-0.1, 0.38, 1.18), (0.07, 0.07, 0.3), SCREEN)
    add("cube", "bento", (0.3, 0.4, 1.08), (0.34, 0.24, 0.1), WOOD)
    add("cube", "bento_bit", (0.22, 0.38, 1.15), (0.1, 0.08, 0.06), CORAL)
    add("cube", "shelf_good", (2.25, 0.45, 1.15), (0.22, 0.16, 0.28), SAGE)
    add("cube", "shelf_good_b", (2.6, 0.42, 1.2), (0.2, 0.16, 0.36), WOOD_D)
    add("cube", "shelf_good_c", (2.95, 0.4, 1.12), (0.18, 0.14, 0.22), CORAL)


def library():
    hide_player()
    sky((0.90, 0.86, 0.78, 1), 0.38)
    look((3.2, -4.2, 2.2), (-0.2, 0.4, 0.95), 32)
    add("cube", "floor", (0, 0.15, -0.04), (7.6, 5.6, 0.08), PATH)
    add("cube", "wall", (0, 2.25, 1.5), (7.4, 0.14, 3.0), PLASTER)
    add("cube", "case", (-2.05, 1.45, 1.15), (1.9, 0.38, 2.2), WOOD)
    add("cube", "case_back", (-2.05, 1.62, 1.15), (1.8, 0.06, 2.05), CREAM)
    colors = (CORAL, SAGE, INK, GOLD, WOOD_D, SAGE_D, CLAY, SCREEN)
    for index in range(9):
        tone = colors[index % len(colors)]
        h = 0.38 + (index % 3) * 0.06
        add("cube", "book_l_%d" % index, (-2.75 + index * 0.18, 1.32, 0.42 + h * 0.5), (0.1, 0.18, h), tone)
        h2 = 0.34 + ((index + 1) % 4) * 0.05
        add("cube", "book_h_%d" % index, (-2.7 + index * 0.17, 1.32, 1.25 + h2 * 0.5), (0.1, 0.16, h2), colors[(index + 3) % len(colors)])
    add("cube", "lean", (-1.15, 1.28, 1.15), (0.08, 0.16, 0.42), CORAL, (0, 0, math.radians(12)))
    add("cube", "table", (0.85, 0.15, 0.42), (1.9, 0.9, 0.07), WOOD)
    for lx, ly in ((0.15, -0.15), (1.55, -0.15), (0.15, 0.45), (1.55, 0.45)):
        add("cube", "leg_%d_%d" % (int(lx * 10), int(ly * 10)), (lx, ly, 0.2), (0.07, 0.07, 0.4), WOOD_D)
    add("cube", "open_l", (0.55, 0.1, 0.49), (0.22, 0.3, 0.02), CREAM, (0, math.radians(8), 0))
    add("cube", "open_r", (0.82, 0.1, 0.49), (0.22, 0.3, 0.02), CREAM, (0, math.radians(-8), 0))
    add("cube", "chair_seat", (0.7, -0.55, 0.4), (0.46, 0.46, 0.06), WOOD)
    add("cube", "chair_back", (0.7, -0.22, 0.72), (0.46, 0.06, 0.55), WOOD)
    add("cyl", "lamp", (1.6, 0.35, 0.85), (0.04, 0.04, 0.7), INK)
    add("cone", "shade", (1.6, 0.35, 1.28), (0.28, 0.28, 0.2), GOLD)
    seat_player((0.7, -0.62, 0.55), math.pi / 2.0)
    _read_book()
    _finish_player()


jobs = [
    ("city", city),
    ("park", park),
    ("cinema", cinema),
    ("gym", gym),
    ("mall", mall),
    ("library", library),
]
only = [name for name in os.environ.get("PLACE_ONLY", "").split(",") if name]
if only:
    jobs = [job for job in jobs if job[0] in only]
gender = os.environ.get("PLACE_GENDER", "f")
suffix = "" if gender == "f" else "_m"
for filename, builder in jobs:
    clear()
    builder()
    render(filename + suffix + ".png")
print("DONE")
