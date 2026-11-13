import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
for s in ['female','male']:
 o=bpy.data.objects[s+'_custom_topology'];bad=[v for v in o.data.vertices if sum(g.weight for g in v.groups)==0];print(s,'BAD',len(bad),[(v.index,tuple(v.co)) for v in bad]);print('GROUPS',[(g.index,g.name) for g in o.vertex_groups])
