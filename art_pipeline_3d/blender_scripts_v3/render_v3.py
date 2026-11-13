import bpy,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parents[1];sys.path.insert(0,str(P/'blender_scripts_v3'));from pose_utils import pose
mode=sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'studio'
blend=P/'blender_realtime_sample.blend' if mode=='v2' else P/'blender_realtime_sample_v3.blend'
bpy.ops.wm.open_mainfile(filepath=str(blend))
sc=bpy.context.scene;sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True;sc.render.threads_mode='FIXED';sc.render.threads=8
sc.render.resolution_percentage=100;sc.render.image_settings.file_format='PNG';cam=sc.camera
for n in ['Room','City','Occlusion','ModuleLibrary']:bpy.data.collections[n].hide_render=True
for sex in ['female','male']:
 a=bpy.data.objects[sex+'_Rig'];a.animation_data.action=None
 for t in a.animation_data.nla_tracks:t.mute=True
 b=bpy.data.objects[sex+'_custom_topology'];b.hide_render=True
 if b.data.shape_keys:
  keys=b.data.shape_keys;keys.animation_data.action=None
  for t in keys.animation_data.nla_tracks:t.mute=True
  keys.key_blocks['SleepLids'].value=0

def character(sex,kind,loc,rot=0):
 a=bpy.data.objects[sex+'_Rig'];b=bpy.data.objects[sex+'_custom_topology'];b.hide_render=False;a.location=loc;a.rotation_euler=(0,0,rot);pose(a,kind)
 if b.data.shape_keys:b.data.shape_keys.key_blocks['SleepLids'].value=1 if kind=='Sleep_Bed' else 0
 bpy.context.view_layer.update();return a,b

def camera(target,scale,offset=(0,-10,.5),res=(1600,1200)):
 cam.location=Vector(target)+Vector(offset);cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=scale;sc.render.resolution_x,sc.render.resolution_y=res

def render(name):sc.render.filepath=str(P/'renders'/name);bpy.ops.render.render(write_still=True)

if mode in ['studio','preview','v2']:
 # Identical studio / camera for both versions, same exposure and matte neutral backdrop.
 for o in sc.objects:
  if o.type=='LIGHT':o.hide_render=True
 sc.world.use_nodes=True;sc.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.60,.65,.70,1);sc.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.32
 for n,loc,energy,size,col in [('Key',(-3,-4,5),450,3,(1,.89,.77)),('Fill',(3,-2,3),160,3,(.78,.87,1)),('Rim',(0,3,4),500,2,(1,.88,.72))]:
  ld=bpy.data.lights.new(n,'AREA');ld.energy=energy;ld.shape='DISK';ld.size=size;ld.color=col;o=bpy.data.objects.new(n,ld);sc.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.9))-o.location).to_track_quat('-Z','Y').to_euler()
 ground=bpy.data.objects['Studio ground'];ground.location.z=-.1
 mat=bpy.data.materials.new('Neutral studio backdrop');mat.use_nodes=True;mat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.22,.25,.26,1);mat.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.95;ground.data.materials.clear();ground.data.materials.append(mat)
 sc.view_settings.exposure=0
 for sex,x in [('female',-.46),('male',.46)]:character(sex,'Idle',(x,0,0))
 camera((0,0,.84),2.65);render('v2_front.png' if mode=='v2' else 'characters_front.png')
 if mode=='preview':sys.exit()
 camera((0,0,.87),2.75,(7,-7,6));render('v2_iso.png' if mode=='v2' else 'characters_iso.png')
 if mode=='v2':sys.exit()
 for sex,x in [('female',-.46),('male',.46)]:character(sex,'Idle',(x,0,0),math.pi/2)
 camera((0,0,.84),2.65);render('characters_side.png')
 for sex,x in [('female',-.46),('male',.46)]:character(sex,'Idle',(x,0,0))
 camera((0,-.015,1.495),1.65,(0,-10,.1),(1800,700));render('faces_detail.png')
 camera((0,-.035,1.0),1.55,(0,-10,1.0),(1800,800));render('garment_detail.png')
 camera((0,-.035,.12),1.55,(4,-10,5),(1800,650));render('shoes_detail.png')
 wiremat=bpy.data.materials.new('Inspection wire');wiremat.use_nodes=True;wiremat.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.015,.027,.023,1)
 for sex in ['female','male']:
  b=bpy.data.objects[sex+'_custom_topology'];w=b.copy();w.data=b.data.copy();sc.collection.objects.link(w);w.data.materials.clear();w.data.materials.append(wiremat);mod=w.modifiers.new('Actual topology edges','WIREFRAME');mod.thickness=.0007;mod.use_replace=True
 camera((0,0,.84),2.65);render('characters_topology.png')
elif mode=='room':
 bpy.data.collections['Room'].hide_render=False
 character('female','Sit_Desk',(.55,1.82,0),math.pi);camera((.55,1.9,.9),3.1,(7,-9,9),(1400,1050));render('pose_sit.png')
 character('female','Sleep_Bed',(-2.6,.38,0));camera((-2.6,1.25,.9),3.5,(7,-7,10),(1400,1050));render('pose_sleep.png')
 character('female','Read_Book',(.55,1.82,0),math.pi);book=bpy.data.objects['Held reading book'];book.location=(.55,2.24,.925);book.rotation_euler=(math.radians(-15),0,math.pi);camera((.55,2.1,.95),3.1,(7,-9,8),(1400,1050));render('pose_read.png');book.location.z=-5
 character('female','Pet_Cat',(-.4,.78,0));camera((-.4,.45,.65),2.9,(7,-9,8),(1400,1050));render('pose_pet.png')
 character('female','Idle',(-.70,1.50,0));character('male','Idle',(-1.48,1.50,0));camera((-1.1,1.50,.95),3.3,(4,-10,5),(1400,1050));render('pose_exit.png')

elif mode=='door':
 bpy.data.collections['Room'].hide_render=False
 character('female','Idle',(-.70,1.50,0));character('male','Idle',(-1.48,1.50,0));camera((-1.1,1.50,.95),3.3,(4,-10,5),(1400,1050));render('pose_exit.png')
