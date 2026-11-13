import bpy,math,sys,os
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parents[1];sys.path.insert(0,str(P/'blender_scripts'));from pose_utils import pose
args=sys.argv[sys.argv.index('--')+1:];mode=args[0];preview='test' in args
bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
sc=bpy.context.scene;cam=sc.camera
C=bpy.data.collections
for name in ['Room','City','Occlusion','ModuleLibrary']:C[name].hide_render=True
for sex in ['male','female']:
 bpy.data.objects[sex+'_custom_topology'].hide_render=True
 arm=bpy.data.objects[sex+'_Rig'];arm.location=(0,0,0);arm.rotation_euler=(0,0,0);arm.animation_data.action=None
 for t in arm.animation_data.nla_tracks:t.mute=True
sc.render.resolution_x=960 if preview else 1920;sc.render.resolution_y=540 if preview else 1080;sc.cycles.samples=12 if preview else (20 if mode=="poses" else 24)
sc.render.threads_mode='FIXED';sc.render.threads=4

def camera(target,scale,front=False):
 target=Vector(target);cam.location=target+(Vector((0,-16,3)) if front else Vector((10,-10,14.1421356)));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=scale

def character(sex,kind,loc,rot=(0,0,0)):
 a=bpy.data.objects[sex+'_Rig'];b=bpy.data.objects[sex+'_custom_topology'];b.hide_render=False;a.location=loc;a.rotation_euler=rot
 if b.data.shape_keys:
  keys=b.data.shape_keys;keys.animation_data.action=None
  for track in keys.animation_data.nla_tracks:track.mute=True
  keys.key_blocks['SleepLids'].value=1 if kind=='Sleep_Bed' else 0
 pose(a,kind);bpy.context.view_layer.update();return a,b

def render(name):
 sc.render.filepath=str(P/'renders'/name);bpy.ops.render.render(write_still=True)

if mode=='room':
 C['Room'].hide_render=False;character('female','Sit_Desk',(.55,1.82,0),(0,0,math.pi));camera((-1,1,1.45),14.8);render('test_room.png' if preview else '02_room_isometric_sit_v2.png')
elif mode=='characters':
 bpy.data.objects['Studio ground'].location.z=-.1 # top at z=0: actual foot contact on the turntable stage
 # Warm neutral turntable floor, no room objects.
 for sex,x in [('female',-.55),('male',.55)]:character(sex,'Idle',(x,0,0))
 camera((0,0,.93),3.6,True);render('test_characters.png' if preview else 'characters_front.png')
 if not preview:
  camera((0,0,.90),3.9);render('characters_iso.png')
  # Actual topology edge overlay and exact deform-bone rods shown alongside unmodified meshes.
  gold=bpy.data.materials.new('Rig overlay ochre');gold.diffuse_color=(.5,.15,.02,1);gold.use_nodes=True;gold.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.5,.15,.02,1)
  for sex in ['female','male']:
   a=bpy.data.objects[sex+'_Rig'];body=bpy.data.objects[sex+'_custom_topology'];wire=body.copy();wire.data=body.data.copy();C['Characters'].objects.link(wire);wire.data.materials.clear();wire.data.materials.append(gold);mod=wire.modifiers.new('Topology inspection edges','WIREFRAME');mod.thickness=.0018;mod.use_replace=True
   for bone in a.pose.bones:
    p=a.matrix_world@bone.head;q=a.matrix_world@bone.tail;p.y-=.16;q.y-=.16
    bpy.ops.mesh.primitive_cylinder_add(vertices=6,radius=.006,depth=(q-p).length,location=(p+q)/2);ob=bpy.context.object;ob.rotation_euler=(q-p).to_track_quat('Z','Y').to_euler();ob.data.materials.append(gold)
  camera((0,0,.93),3.6,True);render('characters_topology.png')
elif mode=='iso_only':
 bpy.data.objects['Studio ground'].location.z=-.1
 for sex,x in [('female',-.55),('male',.55)]:character(sex,'Idle',(x,0,0))
 camera((0,0,.90),3.9);render('characters_iso.png')
elif mode=='poses':
 C['Room'].hide_render=False;female=bpy.data.objects['female_custom_topology'];a=bpy.data.objects['female_Rig']
 if 'onlyexit' not in args:
  # Supine orientation: head toward north pillow, back on mattress z=.71.
  character('female','Sleep_Bed',(-2.6,.38,0),(0,0,0));camera((-2.6,1.15,.85),4.4);render('pose_sleep.png')
  character('female','Read_Book',(.55,1.82,0),(0,0,math.pi));book=bpy.data.objects['Held reading book'];book.location=(.55,2.24,.925);book.rotation_euler=(math.radians(-15),0,math.pi);camera((.55,2.1,.95),3.4);render('pose_read.png');book.location.z=-5
  character('female','Pet_Cat',(-.4,.78,0));camera((-.4,.45,.7),3.4);render('pose_pet.png')
 character('female','Idle',(-1,3.1,0));camera((-1,3.1,1),3.7);render('pose_exit.png')
elif mode=='city':
 C['City'].hide_render=False;camera((0,0,1),49.5);render('05_city_overview_isometric.png')
elif mode=='landmarks':
 sc.cycles.samples=8
 C['City'].hide_render=False
 for n,x,y in [('home',-8,6),('cinema',-8,-7),('library',-.5,6),('gym',9,6),('mall',9,-7),('park',-.5,-7)]:
  camera((x,y,1.5),14.8);render('city_'+n+'.png')
elif mode=='dither':
 C['Occlusion'].hide_render=False;character('female','Idle',(0,.1,0));camera((0,0,.9),4.7)
 wall=bpy.data.objects['Occluding wall'];d=wall.data.materials[0];wall.data.materials[0]=bpy.data.materials['wall'];render('occlusion_before.png');wall.data.materials[0]=d;render('occlusion_after.png')
