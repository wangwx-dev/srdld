import bpy,json,math
from pathlib import Path
P=Path(__file__).resolve().parents[1];bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
mods=[o for o in bpy.data.collections['Room'].objects if o.name.startswith(('floor_tile_2x2','wall_back_2x3','wall_corner_in_2x2x3','wall_low_front_2x05','wall_window_2x3','door_module_2x3'))]
placements=[{'name':o.name,'location_m':list(o.location),'grid_error_m':[abs(x/2-round(x/2))*2 for x in o.location],'quarter_turn_error_degrees':abs(math.degrees(o.rotation_euler.z)/90-round(math.degrees(o.rotation_euler.z)/90))*90} for o in mods]
chars={}
for sex in ['female','male']:
 b=bpy.data.objects[sex+'_custom_topology'];a=bpy.data.objects[sex+'_Rig'];b.data.calc_loop_triangles()
 head=[v.co.z for v in b.data.vertices if any(b.vertex_groups[g.group].name=='Head' and g.weight>.99 for g in v.groups)]
 chars[sex]={'source_triangles':len(b.data.loop_triangles),'bone_count':len(a.data.bones),'mesh_height_m':max(v.co.z for v in b.data.vertices)-min(v.co.z for v in b.data.vertices),'head_region_height_m':max(head)-min(head),'head_units':(max(v.co.z for v in b.data.vertices)-min(v.co.z for v in b.data.vertices))/(max(head)-min(head)),'face_texture_pixels':list(bpy.data.images[sex+'_face.png'].size),'uv_layers':len(b.data.uv_layers),'morph_keys':list(b.data.shape_keys.key_blocks.keys())}
(P/'evidence/source_audit_v2.json').write_text(json.dumps({'placements':placements,'characters':chars},indent=2));print(json.dumps(chars,indent=2))
