import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];sys.path.insert(0,str(P/'blender_scripts'));from pose_utils import pose
bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
dg=bpy.context.evaluated_depsgraph_get()
for o in bpy.data.collections['Room'].objects:
 if o.type!='MESH':continue
 me=o.evaluated_get(dg).to_mesh();me.calc_loop_triangles();n=sum((me.vertices[t.vertices[1]].co-me.vertices[t.vertices[0]].co).cross(me.vertices[t.vertices[2]].co-me.vertices[t.vertices[0]].co).length_squared<1e-18 for t in me.loop_triangles)
 if n:print('TINY',o.name,n,flush=True)
 o.evaluated_get(dg).to_mesh_clear()
