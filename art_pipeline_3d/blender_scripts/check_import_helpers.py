import bpy
from pathlib import Path
P=Path(__file__).resolve().parents[1];bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(P/'exports/female_rigged.glb'))
for o in bpy.data.objects:
 if o.type=='MESH':print('MESH',o.name,len(o.data.vertices),len(o.data.polygons),'hiddenRender',o.hide_render,'groups',len(o.vertex_groups),'unweighted',sum(sum(g.weight for g in v.groups)==0 for v in o.data.vertices))
