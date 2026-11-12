"""Clay dioramas for the city and each outing, same palette as the room."""
import math
import os
from mathutils import Vector
from pathlib import Path

import bpy

OUT = Path(__file__).resolve().parents[2] / "assets" / "places"
FONT_PATH = Path(__file__).resolve().parents[2] / "assets" / "fonts" / "SourceHanSansCN-Regular.otf"
OUT.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.eevee.taa_render_samples = 24
scene.render.resolution_x = 1440
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.film_transparent = False
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGB"
scene.world = bpy.data.worlds.new("PlaceSky")
scene.world.use_nodes = True

cam_data = bpy.data.cameras.new("PlaceCam")
cam_data.lens = 38
cam = bpy.data.objects.new("PlaceCam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

sun_data = bpy.data.lights.new("Sun", "SUN")
sun_data.energy = 3.4
sun = bpy.data.objects.new("Sun", sun_data)
scene.collection.objects.link(sun)
sun.rotation_euler = (math.radians(48), math.radians(8), math.radians(24))
fill_data = bpy.data.lights.new("Fill", "AREA")
fill_data.energy = 280
fill_data.size = 6
fill = bpy.data.objects.new("Fill", fill_data)
scene.collection.objects.link(fill)
fill.location = (-2.5, -3.5, 3.4)

FONT = bpy.data.fonts.load(str(FONT_PATH))


def mat(name, color):
    item = bpy.data.materials.new(name)
    item.use_nodes = True
    node = item.node_tree.nodes["Principled BSDF"]
    node.inputs["Base Color"].default_value = color
    node.inputs["Roughness"].default_value = 0.62
    return item


CLAY = mat("Clay", (0.90, 0.62, 0.55, 1))
SAGE = mat("Sage", (0.56, 0.72, 0.66, 1))
SAGE_D = mat("SageDark", (0.32, 0.48, 0.44, 1))
WOOD = mat("Wood", (0.72, 0.55, 0.36, 1))
WOOD_D = mat("WoodDark", (0.45, 0.30, 0.18, 1))
CREAM = mat("Cream", (0.96, 0.93, 0.86, 1))
INK = mat("Ink", (0.22, 0.26, 0.28, 1))
GRASS = mat("Grass", (0.62, 0.74, 0.52, 1))
PATH = mat("Path", (0.86, 0.78, 0.62, 1))
SCREEN = mat("Screen", (0.75, 0.84, 0.88, 1))
GOLD = mat("Gold", (0.86, 0.67, 0.32, 1))
WALL = mat("Wall", (0.93, 0.90, 0.84, 1))

made = []


def sky(color, strength=0.85):
    scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = color
    scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = strength


def look(location, target, lens=38):
    cam.location = Vector(location)
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


def add(kind, name, loc, scale, material, rot=(0, 0, 0)):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=0.5, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=20, radius=0.5, depth=1, location=loc)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=0.5, depth=1, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = Vector(scale)
    obj.rotation_euler = rot
    obj.data.materials.append(material)
    made.append(obj)
    return obj


def clear():
    for obj in list(made):
        bpy.data.objects.remove(obj, do_unlink=True)
    made.clear()


def sign(name, text, loc, material, size=0.28, rot=(math.radians(68), 0, math.radians(18))):
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = text
    curve.font = FONT
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = 0.02
    curve.materials.append(material)
    obj = bpy.data.objects.new(name, curve)
    obj.location = Vector(loc)
    obj.rotation_euler = rot
    scene.collection.objects.link(obj)
    made.append(obj)
    return obj


def tree(name, loc, scale=1.0):
    add("cyl", name + "_trunk", (loc[0], loc[1], 0.55 * scale), (0.14 * scale, 0.14 * scale, 1.1 * scale), WOOD_D)
    add("sphere", name + "_leaf", (loc[0], loc[1], 1.35 * scale), (1.05 * scale, 1.05 * scale, 0.85 * scale), SAGE_D)
    add("sphere", name + "_leaf_b", (loc[0] + 0.15 * scale, loc[1] - 0.1, 1.05 * scale), (0.7 * scale, 0.7 * scale, 0.55 * scale), SAGE)


def person(name, loc, shirt):
    add("sphere", name + "_head", (loc[0], loc[1], loc[2] + 0.78), (0.22, 0.22, 0.22), CLAY)
    add("cube", name + "_body", (loc[0], loc[1], loc[2] + 0.46), (0.32, 0.18, 0.38), shirt)
    add("cube", name + "_leg", (loc[0] - 0.07, loc[1], loc[2] + 0.16), (0.09, 0.09, 0.32), INK)
    add("cube", name + "_legb", (loc[0] + 0.07, loc[1], loc[2] + 0.16), (0.09, 0.09, 0.32), INK)


def render(name):
    scene.render.filepath = str(OUT / name)
    bpy.ops.render.render(write_still=True)
    print("WROTE", name)


def city():
    sky((0.78, 0.86, 0.84, 1), 1.0)
    look((7.4, -9.2, 6.2), (0.6, 0.8, 0.7), 32)
    add("cube", "ground", (0.2, 0.4, -0.06), (11.5, 7.2, 0.1), GRASS)
    add("cube", "road", (0.2, -0.55, 0.02), (11.2, 1.35, 0.05), PATH)
    add("cube", "lane", (0.2, -0.55, 0.055), (8.4, 0.06, 0.02), CREAM)
    for index in range(5):
        add("cube", "cross_%d" % index, (-1.6 + index * 0.28, -1.15, 0.055), (0.16, 0.7, 0.02), CREAM)
    tree("park_t1", (-4.0, 1.5), 0.85)
    tree("park_t2", (-3.1, 2.0), 0.7)
    add("cube", "park_gate", (-3.5, 0.55, 0.85), (1.7, 0.12, 1.6), SAGE)
    add("cube", "park_path", (-3.5, -0.15, 0.04), (0.7, 1.3, 0.04), PATH)
    sign("park_sign", "公园", (-3.5, 0.42, 1.35), CREAM, 0.32)
    add("cube", "cinema", (-1.15, 1.35, 1.05), (1.7, 1.15, 2.1), INK)
    add("cube", "marquee", (-1.15, 0.72, 1.75), (1.6, 0.08, 0.32), GOLD)
    add("cube", "screen", (-1.15, 0.74, 0.95), (1.0, 0.05, 0.62), SCREEN)
    sign("cinema_sign", "影院", (-1.15, 0.62, 1.75), INK, 0.26)
    add("cube", "library", (0.85, 2.15, 1.35), (1.35, 0.95, 2.7), WOOD)
    add("cube", "lib_win", (0.85, 1.64, 1.45), (0.85, 0.06, 1.35), SCREEN)
    add("cube", "lib_door", (0.85, 1.64, 0.55), (0.38, 0.06, 0.9), WOOD_D)
    sign("lib_sign", "图书馆", (0.85, 1.5, 2.35), CREAM, 0.24)
    add("cube", "mall", (3.15, 1.25, 0.95), (2.5, 1.25, 1.9), CREAM)
    add("cube", "awning_a", (2.35, 0.55, 1.35), (0.7, 0.4, 0.1), CLAY)
    add("cube", "awning_b", (3.15, 0.55, 1.35), (0.7, 0.4, 0.1), SAGE)
    add("cube", "awning_c", (3.95, 0.55, 1.35), (0.7, 0.4, 0.1), GOLD)
    sign("mall_sign", "商场", (3.15, 0.4, 1.7), INK, 0.28)
    add("cube", "gym", (5.15, 1.35, 0.9), (1.45, 1.15, 1.8), SAGE)
    add("cyl", "bar", (5.15, 0.7, 1.25), (0.85, 0.08, 0.08), WOOD_D, (0, math.radians(90), 0))
    add("cyl", "plate_a", (4.55, 0.7, 1.25), (0.28, 0.28, 0.1), INK)
    add("cyl", "plate_b", (5.75, 0.7, 1.25), (0.28, 0.28, 0.1), INK)
    sign("gym_sign", "健身", (5.15, 0.55, 1.7), CREAM, 0.24)


def park():
    sky((0.74, 0.86, 0.92, 1), 1.05)
    look((3.4, -4.2, 2.5), (0.1, 0.2, 0.5), 36)
    add("cube", "grass", (0, 0.2, -0.05), (8.5, 6.2, 0.1), GRASS)
    add("cube", "path", (-0.2, -0.1, 0.02), (1.35, 5.6, 0.05), PATH)
    tree("t1", (-2.5, 1.3))
    tree("t2", (2.3, 1.1), 0.9)
    tree("t3", (-2.0, -1.5), 0.75)
    tree("t4", (2.6, -1.2), 0.7)
    add("cube", "bench_seat", (1.15, 0.15, 0.42), (1.45, 0.42, 0.08), WOOD)
    add("cube", "bench_back", (1.15, 0.38, 0.72), (1.45, 0.08, 0.5), WOOD)
    add("cube", "bench_leg", (0.6, 0.15, 0.2), (0.1, 0.36, 0.4), WOOD_D)
    add("cube", "bench_leg_b", (1.7, 0.15, 0.2), (0.1, 0.36, 0.4), WOOD_D)
    add("sphere", "flower", (-1.3, 0.8, 0.12), (0.55, 0.4, 0.16), CLAY)
    add("sphere", "flower_b", (-1.5, 1.15, 0.1), (0.4, 0.3, 0.12), GOLD)
    add("cyl", "lamp", (2.15, -0.85, 0.7), (0.06, 0.06, 1.4), INK)
    add("sphere", "lamp_head", (2.15, -0.85, 1.45), (0.28, 0.28, 0.18), GOLD)
    person("sitter", (1.15, -0.05, 0.46), SAGE)


def cinema():
    sky((0.07, 0.08, 0.09, 1), 0.35)
    look((0.35, -4.2, 2.55), (0.0, 0.6, 0.95), 30)
    add("cube", "floor", (0, 0.2, -0.04), (6.4, 5.4, 0.08), INK)
    add("cube", "back", (0, 2.35, 1.45), (6.2, 0.16, 2.9), INK)
    add("cube", "side_l", (-3.15, 0.1, 1.45), (0.16, 5.0, 2.9), INK)
    add("cube", "side_r", (3.15, 0.1, 1.45), (0.16, 5.0, 2.9), INK)
    add("cube", "screen", (0, 2.2, 1.55), (3.6, 0.08, 1.7), SCREEN)
    add("cube", "screen_pic", (-0.45, 2.14, 1.65), (1.3, 0.03, 0.85), CLAY)
    add("cube", "screen_hill", (0.55, 2.14, 1.25), (1.5, 0.03, 0.4), SAGE)
    for row in range(4):
        y = 0.85 - row * 0.72
        z = 0.32 + row * 0.08
        add("cube", "row_%d" % row, (0.15, y, z), (4.4, 0.42, 0.28), SAGE_D)
        add("cube", "back_%d" % row, (0.15, y + 0.22, z + 0.48), (4.4, 0.1, 0.62), INK)
    person("viewer", (-0.55, 0.55, 0.42), CLAY)


def gym():
    sky((0.86, 0.90, 0.88, 1))
    look((3.2, -3.6, 2.15), (0.2, 0.2, 0.7), 34)
    add("cube", "floor", (0, 0, -0.04), (7.2, 5.2, 0.08), CREAM)
    add("cube", "wall", (0, 2.15, 1.35), (7.2, 0.16, 2.7), SAGE)
    add("cube", "mirror", (-0.4, 2.05, 1.45), (3.2, 0.04, 1.3), SCREEN)
    add("cube", "mat", (-1.7, 0.15, 0.04), (2.3, 1.5, 0.06), SAGE_D)
    add("cyl", "bell_a", (-1.85, 0.15, 0.28), (0.32, 0.32, 0.28), WOOD_D)
    add("cyl", "bell_b", (-0.95, -0.15, 0.24), (0.26, 0.26, 0.22), INK)
    add("cube", "bench", (1.55, 0.25, 0.38), (1.7, 0.42, 0.16), WOOD)
    add("cube", "bench_leg", (0.9, 0.25, 0.16), (0.1, 0.36, 0.32), WOOD_D)
    add("cube", "bench_leg_b", (2.2, 0.25, 0.16), (0.1, 0.36, 0.32), WOOD_D)
    add("cyl", "rack", (1.55, 0.05, 1.15), (0.07, 0.07, 1.5), INK, (0, math.radians(90), 0))
    add("cyl", "plate_l", (0.85, 0.05, 1.15), (0.32, 0.32, 0.08), WOOD_D, (0, math.radians(90), 0))
    add("cyl", "plate_r", (2.25, 0.05, 1.15), (0.32, 0.32, 0.08), WOOD_D, (0, math.radians(90), 0))
    person("lifter", (1.55, -0.7, 0.0), SAGE)


def mall():
    sky((0.93, 0.90, 0.86, 1))
    look((0.2, -4.4, 2.05), (0.1, 0.6, 0.85), 34)
    add("cube", "floor", (0, 0, -0.04), (8.6, 5.4, 0.08), PATH)
    add("cube", "back", (0, 2.05, 1.45), (8.2, 0.18, 2.9), WALL)
    shops = [(-2.5, CLAY, "吃的"), (0.0, SAGE, "家具"), (2.5, WOOD, "日用")]
    for index, (x, color, title) in enumerate(shops):
        add("cube", "front_%d" % index, (x, 1.15, 1.15), (2.15, 0.12, 2.2), CREAM)
        add("cube", "window_%d" % index, (x, 1.08, 1.35), (1.35, 0.05, 0.85), SCREEN)
        add("cube", "counter_%d" % index, (x, 0.35, 0.48), (1.7, 0.7, 0.9), CREAM)
        add("cube", "awning_%d" % index, (x, 0.15, 1.85), (2.0, 0.55, 0.1), color)
        add("cube", "good_%d" % index, (x - 0.35, 0.45, 1.05), (0.32, 0.28, 0.32), color)
        add("cyl", "bottle_%d" % index, (x + 0.25, 0.4, 1.12), (0.12, 0.12, 0.38), GOLD)
        add("cube", "box_%d" % index, (x + 0.05, 0.55, 1.02), (0.28, 0.22, 0.18), WOOD_D)
        sign("label_%d" % index, title, (x, 0.05, 2.15), INK, 0.22, (math.radians(78), 0, 0))


def library():
    sky((0.93, 0.89, 0.82, 1))
    look((2.8, -3.8, 2.15), (-0.4, 0.5, 0.9), 34)
    add("cube", "floor", (0, 0.1, -0.04), (7.4, 5.4, 0.08), PATH)
    add("cube", "wall", (0, 2.2, 1.5), (7.2, 0.16, 3.0), WALL)
    add("cube", "shelf", (-2.15, 1.55, 1.15), (1.7, 0.42, 2.2), WOOD)
    colors = (CLAY, SAGE, INK, GOLD, WOOD_D, SAGE_D)
    for index in range(8):
        tone = colors[index % len(colors)]
        add("cube", "book_l_%d" % index, (-2.75 + index * 0.18, 1.38, 0.72), (0.12, 0.22, 0.46), tone)
        add("cube", "book_h_%d" % index, (-2.7 + index * 0.17, 1.38, 1.55), (0.11, 0.2, 0.4), colors[(index + 2) % len(colors)])
    add("cube", "table", (0.85, 0.15, 0.42), (1.9, 0.9, 0.08), WOOD)
    add("cube", "leg", (0.15, -0.15, 0.2), (0.08, 0.08, 0.4), WOOD_D)
    add("cube", "leg_b", (1.55, -0.15, 0.2), (0.08, 0.08, 0.4), WOOD_D)
    add("cube", "leg_c", (0.15, 0.45, 0.2), (0.08, 0.08, 0.4), WOOD_D)
    add("cube", "leg_d", (1.55, 0.45, 0.2), (0.08, 0.08, 0.4), WOOD_D)
    add("cube", "open", (0.7, 0.1, 0.5), (0.48, 0.34, 0.035), CREAM)
    add("cube", "chair", (0.7, -0.55, 0.28), (0.46, 0.46, 0.08), WOOD)
    add("cube", "chair_back", (0.7, -0.75, 0.58), (0.46, 0.08, 0.5), WOOD)
    add("cyl", "lamp", (1.55, 0.35, 0.85), (0.05, 0.05, 0.7), INK)
    add("cone", "shade", (1.55, 0.35, 1.25), (0.28, 0.28, 0.22), GOLD)
    person("reader", (0.7, -0.35, 0.32), SAGE)


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
for filename, builder in jobs:
    clear()
    builder()
    render(filename + ".png")

print("DONE")
