import bpy,json,sys,collections,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parents[1];sys.path.insert(0,str(P/'blender_scripts_v3'));from pose_utils import pose
bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample_v3.blend'))
result={}
for sex in ['female','male']:
 b=bpy.data.objects[sex+'_custom_topology'];a=bpy.data.objects[sex+'_Rig'];me=b.data;me.calc_loop_triangles()
 faces=collections.Counter(tuple(sorted(tuple(round(x,7) for x in me.vertices[i].co) for i in f.vertices)) for f in me.polygons)
 tr=collections.Counter(tuple(sorted(tuple(round(x,7) for x in me.vertices[i].co) for i in t.vertices)) for t in me.loop_triangles)
 a.animation_data.action=None
 for t in a.animation_data.nla_tracks:t.mute=True
 matrices={}
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  pose(a,kind)
  b.data.shape_keys.key_blocks['SleepLids'].value=1 if kind=='Sleep_Bed' else 0
  bpy.context.view_layer.update();ev=b.evaluated_get(bpy.context.evaluated_depsgraph_get());posed=ev.to_mesh();posed.calc_loop_triangles();deg=sum(t.area<1e-10 for t in posed.loop_triangles);mina=min(t.area for t in posed.loop_triangles);ev.to_mesh_clear()
  head=a.pose.bones['Head'];rest=head.bone.matrix_local;deform=head.matrix@rest.inverted();cols=deform.to_3x3().col
  matrices[kind]={'head_deform_axis_lengths':[c.length for c in cols],'head_deform_determinant':deform.to_3x3().determinant(),'posed_degenerate_triangles':deg,'posed_min_triangle_area_m2':mina,'finite_matrices':all(math.isfinite(v) for pb in a.pose.bones for row in pb.matrix for v in row)}
 result[sex]={'triangles':len(me.loop_triangles),'vertices':len(me.vertices),'bones':len(a.data.bones),'head_inherit_scale':a.data.bones['Head'].inherit_scale,'shape_keys':list(me.shape_keys.key_blocks.keys()),'unweighted_vertices':sum(not any(g.weight>0 for g in v.groups) for v in me.vertices),'weight_sum_max_error':max(abs(1-sum(g.weight for g in v.groups)) for v in me.vertices),'duplicate_faces_by_coordinates':sum(c-1 for c in faces.values()),'duplicate_triangles_by_coordinates':sum(c-1 for c in tr.values()),'degenerate_triangles':sum(t.area<1e-10 for t in me.loop_triangles),'poses':matrices,'materials':[m.name for m in me.materials]}
(P/'evidence/source_audit.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
