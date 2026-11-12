from pathlib import Path
import bpy, math,json
from mathutils import Vector,Matrix
from bpy_extras.object_utils import world_to_camera_view
OUT=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(OUT/'source/v1_input.blend'))
s=bpy.context.scene
# Furniture, chair and character are transformed together, retaining all pose contacts.
pivot=Vector((2.07,.35,0)); new=Vector((1.80,-.20,0))
R=Matrix.Rotation(math.pi,4,'Z'); transform=Matrix.Translation(new)@R@Matrix.Translation(-pivot)
# Enlarge complete monitor display and original drawn content consistently before turning workstation.
screen_center=Vector((2.43,.46,1.88))
S=Matrix.Translation(screen_center+Vector((0,0,.13)))@Matrix.Diagonal((1,1.42,1.40,1))@Matrix.Translation(-screen_center)
screen_objects=[]
for o in bpy.data.collections['20_Desk'].objects:
    if o.name in {'Monitor_bezel','Monitor_screen'} or o.name.startswith('Screen_'):
        o.matrix_world=S@o.matrix_world;screen_objects.append(o)
# Scale the support stem upward while keeping its base rooted on the desk.
o=bpy.data.objects['Monitor_stem']; o.location.z+=.065;o.scale.z*=1.54
for cn in ['20_Desk','21_DeskUpgrade','30_Chair','50_Character_F01_Seated']:
    for o in bpy.data.collections[cn].objects:o.matrix_world=transform@o.matrix_world
# Expand room on the right, preserve original bed/window/bookcase layout.
for name,width in [('Foundation_shadow_reveal',7.74),('Back_wall',7.74),('Back_baseboard',7.54),('Back_top_trim',7.79)]:
    o=bpy.data.objects[name]; o.location.x=.77; o.dimensions.x=width
structure=bpy.data.collections['00_Structure']
oak=bpy.data.materials['03_Honey ash'];linen=bpy.data.materials['06_Unbleached linen'];sage=bpy.data.materials['08_Deep sage textile'];walnut=bpy.data.materials['05_Walnut edges'];brass=bpy.data.materials['10_Brushed brass'];dark=bpy.data.materials['09_Ink green'];pale=bpy.data.materials['04_Pale endgrain']
def box(name,loc,size,material,collection,bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o);o.data.materials.append(material)
    if bevel:
        m=o.modifiers.new('Consistent rounded joinery','BEVEL');m.width=bevel;m.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o
for i in range(4):
    x=3.28+i*.385
    for j,(y,length) in enumerate([(-1.72,1.72),(0,1.68),(1.72,1.72)]):box(f'Floor_extension_{i}_{j}',(x,y,-.015),(.377,length,.12),oak,structure,.012)
# New door: closed state only; real named mesh collection, not UI painted on wall.
coll=bpy.data.collections.new('70_ExitDoor');s.collection.children.link(coll)
box('Door_shadow_recess',(3.35,2.443,1.40),(1.32,.055,2.68),walnut,coll,.025)
box('Door_leaf',(3.35,2.375,1.39),(1.15,.085,2.57),sage,coll,.035)
for x in [2.69,4.01]:box('Door_frame_stile',(x,2.34,1.40),(.12,.18,2.64),linen,coll,.022)
box('Door_frame_header',(3.35,2.34,2.79),(1.44,.18,.14),linen,coll,.022)
box('Door_threshold',(3.35,2.31,.075),(1.34,.30,.055),pale,coll,.018)
# Muted inset panels and lever make object legibly a door.
for z,h in [(1.89,.97),(.75,.79)]:
    box('Door_recessed_panel',(3.35,2.322,z),(.89,.018,h),dark,coll,.035)
    box('Door_panel_infill',(3.35,2.308,z),(.82,.016,h-.07),sage,coll,.025)
box('Door_handle_plate',(2.96,2.272,1.34),(.055,.035,.20),brass,coll,.017)
box('Door_lever',(3.045,2.235,1.36),(.20,.04,.04),brass,coll,.016)
for z in [.40,2.27]:box('Door_hinge',(3.92,2.29,z),(.04,.055,.15),brass,coll,.013)
# Baseboard must not run through the opening: replace original bar by two spans.
o=bpy.data.objects['Back_baseboard'];o.hide_render=True;o.hide_viewport=True
box('Back_baseboard_left_of_door',(-.15,2.44,.14),(5.56,.08,.24),linen,structure,.02)
box('Back_baseboard_right_of_door',(4.28,2.44,.14),(.40,.08,.24),linen,structure,.02)
# Shift rug below new seating footprint; it no longer needs to pretend pose is unchanged.
rug=bpy.data.objects['Rug_main'];rug.location.x=1.50;rug.dimensions.x=3.95
for o in list(structure.objects):
    if o.name.startswith('Rug_woven_border'):o.location.x=1.50;o.dimensions.x=3.65
# Camera keeps true perspective but gives expanded room breathing space.
cam=s.camera;cam.location=(11,-13,10);target=Vector((.70,.10,1.18));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.lens=53
s.render.resolution_x=1760;s.render.resolution_y=1400;s.render.resolution_percentage=100
s.cycles.samples=72;s.render.threads_mode='FIXED';s.render.threads=8;s.render.film_transparent=True
s['sample_status']='v2 art + static interaction visual demo ONLY; no actual click handlers, Godot code or travel system.'
s['v2_changes']='Workstation, character and chair rotated together 180 degrees; monitor display x1.42 wide x1.40 high; room expanded rightward 1.54m; visible modeled door.'
# Pixel anchors are exported from real 3D points, top-left origin and same source camera.
anchors={
 'computer':{'label':'创作','collection':'20_Desk','world':list(transform@(S@Vector((2.37,.46,2.18))))},
 'bed':{'label':'休息','collection':'10_Bed','world':[-1.70,-.25,.97]},
 'bookshelf':{'label':'阅读','collection':'40_Bookcase','world':[.05,1.78,2.62]},
 'door':{'label':'出门','collection':'70_ExitDoor','world':[3.35,2.27,2.80]}}
def pixel(co):
    p=world_to_camera_view(s,cam,Vector(co));return [p.x*s.render.resolution_x,(1-p.y)*s.render.resolution_y]
bpy.context.view_layer.update()
for k,v in anchors.items():v['pixel']=pixel(v['world'])
# Face corner polygon exported for one restrained selected highlight in detachable overlay.
corners=[]
for y,z in [(-.45,-.275),(.45,-.275),(.45,.275),(-.45,.275)]:
    corners.append(pixel(transform@(S@Vector((2.366,.46+y,1.89+z)))))
data={'version':2,'canvas':[1760,1400],'coordinate_origin':'top-left','camera_type':cam.data.type,'camera_lens_mm':cam.data.lens,'camera_matrix_world':[list(r) for r in cam.matrix_world],'anchors':anchors,'selected_monitor_face_polygon':corners,'warning':'Static art prototype only. Anchor pixels are not collision polygons or implemented clicks.'}
(OUT/'hotspot_anchors.json').write_text(json.dumps(data,ensure_ascii=False,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'room_sample_v2.blend'))
s.render.filepath=str(OUT/'renders/room_v2_clean.png');bpy.ops.render.render(write_still=True)
# A source-neutral desk+computer isolated export with correct camera; character remains separate.
for o in s.objects:
    if o.type in {'MESH','CURVE'} and o not in set(bpy.data.collections['20_Desk'].all_objects):o.hide_render=True
s.cycles.samples=32;s.render.filepath=str(OUT/'layers/workstation_v2.png');bpy.ops.render.render(write_still=True)
print('V2_BUILD_COMPLETE',flush=True)
