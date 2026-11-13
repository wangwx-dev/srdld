import bpy,json,math
from pathlib import Path
P=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'));dg=bpy.context.evaluated_depsgraph_get();result=[]
for o in bpy.data.objects:
 if o.type!='MESH':continue
 ev=o.evaluated_get(dg);me=ev.to_mesh();me.calc_loop_triangles();coords=[v.co for v in o.data.vertices];mn=[min(v[i] for v in coords) for i in range(3)];mx=[max(v[i] for v in coords) for i in range(3)]
 mats=[]
 for m in o.data.materials:
  imgs=[n.image for n in m.node_tree.nodes if n.type=='TEX_IMAGE' and n.image] if m and m.use_nodes else []
  mats.append({'material':m.name if m else None,'images':[i.name for i in imgs],'source':m.get('source','author-created/graphic or organic material') if m else None})
 result.append({'object':o.name,'collections':[c.name for c in o.users_collection],'vertices':len(o.data.vertices),'quads':sum(len(f.vertices)==4 for f in o.data.polygons),'triangles_evaluated':len(me.loop_triangles),'origin_local':[float(v) for v in o.location],'origin_world':[float(v) for v in o.matrix_world.translation],'bbox_local_min':mn,'bbox_local_max':mx,'uv_layers':[u.name for u in o.data.uv_layers],'materials':mats});ev.to_mesh_clear()
(P/'evidence/scene_assets.json').write_text(json.dumps(result,indent=2));print('AUDITED',len(result),'mesh objects')
