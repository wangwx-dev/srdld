import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
o=bpy.data.objects['female_custom_topology'];print('MATS',[(i,m.name) for i,m in enumerate(o.data.materials)])
idx=next(i for i,m in enumerate(o.data.materials) if m.name=='female painted subtle face');print('FACE UV',[(list(o.data.vertices[o.data.loops[li].vertex_index].co),list(o.data.uv_layers.active.data[li].uv)) for f in o.data.polygons if f.material_index==idx for li in f.loop_indices][:50]);print('FACE NODES',[(n.name,n.image.name if n.type=='TEX_IMAGE' else None) for n in o.data.materials[idx].node_tree.nodes]);print('UV LAYERS',[(u.name,u.active_render) for u in o.data.uv_layers]);print('ACTIONS',[(a.name,a.frame_range[:]) for a in bpy.data.actions])
