import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
P=Path(__file__).resolve().parents[1];sys.path.insert(0,str(P/'blender_scripts'));from pose_utils import pose
bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
sc=bpy.context.scene

def tree(objects):
 v=[];f=[];dg=bpy.context.evaluated_depsgraph_get()
 for o in objects:
  ev=o.evaluated_get(dg);me=ev.to_mesh();off=len(v);v.extend(o.matrix_world@vv.co for vv in me.vertices);f.extend(tuple(off+i for i in p.vertices) for p in me.polygons);ev.to_mesh_clear()
 return BVHTree.FromPolygons(v,f)
room=list(bpy.data.collections['Room'].objects)
keyboard=tree([o for o in room if o.name.startswith(('Keyboard slab','Keycap'))])
cathead=tree([bpy.data.objects['Cat head']]);duvet=tree([bpy.data.objects['Duvet with folded upper edge']]);pillow=tree([o for o in room if o.name.startswith('Pillow with loft')])
book=bpy.data.objects['Held reading book'];book.location=(.55,2.24,.925);book.rotation_euler=(math.radians(-15),0,math.pi);bpy.context.view_layer.update();booktree=tree([book])
results={}
for sex in ['female','male']:
 arm=bpy.data.objects[sex+'_Rig'];body=bpy.data.objects[sex+'_custom_topology'];arm.animation_data.action=None
 for tr in arm.animation_data.nla_tracks:tr.mute=True
 if body.data.shape_keys:
  keys=body.data.shape_keys;keys.animation_data.action=None
  for tr in keys.animation_data.nla_tracks:tr.mute=True
 byname={g.name:g.index for g in body.vertex_groups}
 groups={name:[v.index for v in body.data.vertices if any(g.group==idx and g.weight>.6 for g in v.groups)] for name,idx in byname.items()}
 results[sex]={}
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  arm.location={'Sleep_Bed':(-2.6,.38,0),'Pet_Cat':(-.4,.78,0)}.get(kind,(.55,1.82,0) if kind in ['Sit_Desk','Read_Book'] else (-1,3.1,0))
  arm.rotation_euler=(0,0,math.pi if kind in ['Sit_Desk','Read_Book'] else 0)
  pose(arm,kind)
  if body.data.shape_keys:body.data.shape_keys.key_blocks['SleepLids'].value=1 if kind=='Sleep_Bed' else 0
  bpy.context.view_layer.update();ev=body.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh();verts=[body.matrix_world@v.co for v in me.vertices]
  def distance(names,bvh):return min(bvh.find_nearest(verts[i])[3] for name in names for i in groups[name])
  feet=['LeftFoot','RightFoot','LeftToeBase','RightToeBase'];hands=['LeftHand','RightHand']
  r={}
  if kind in ['Idle','Sit_Desk','Read_Book','Pet_Cat']:r['foot_lowest_world_z_m']=min(verts[i].z for name in feet for i in groups[name])
  if kind=='Sit_Desk':
   r['hand_keyboard_surface_gap_m']={side:distance([side+'Hand'],keyboard) for side in ['Left','Right']}
   r['chair_back_penetrating_vertices']=sum(.30<p.x<.80 and 1.44<p.y<1.52 and .55<p.z<1.01 for p in verts)
  if kind=='Read_Book':
   r['hand_book_surface_gap_m']={side:distance([side+'Hand'],booktree) for side in ['Left','Right']}
   for side in ['Left','Right']:
    ids=groups[side+'Hand'];idx=min(ids,key=lambda i:booktree.find_nearest(verts[i])[3]);print('BOOK',sex,side,list(verts[idx]),list(booktree.find_nearest(verts[idx])[0]),flush=True)
  if kind=='Pet_Cat':r['closest_hand_cat_head_gap_m']=distance(hands,cathead)
  if kind=='Sleep_Bed':
   r['shoe_duvet_gap_m']={side:distance([side+'Foot',side+'ToeBase'],duvet) for side in ['Left','Right']}
   r['head_pillow_surface_gap_m']=distance(['Head'],pillow)
  results[sex][kind]=r;ev.to_mesh_clear()
(P/'evidence/contact_qc_v2.json').write_text(json.dumps(results,indent=2));print(json.dumps(results,indent=2))
