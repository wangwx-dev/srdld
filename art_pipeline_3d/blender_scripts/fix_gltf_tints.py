import bpy,sys,math
from math import pi
from pathlib import Path
P=Path(__file__).resolve().parents[1];sys.path.insert(0,str(P/'blender_scripts'));from pose_utils import pose
bpy.ops.wm.open_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
for m in bpy.data.materials:
 if not m.use_nodes:continue
 nt=m.node_tree
 for old in list(nt.nodes):
  if old.type!='MIX_RGB':continue
  new=nt.nodes.new('ShaderNodeMix');new.data_type='RGBA';new.blend_type=old.blend_type;new.inputs[0].default_value=old.inputs[0].default_value
  for index,newindex in [(1,6),(2,7)]:
   new.inputs[newindex].default_value=old.inputs[index].default_value
   for l in list(old.inputs[index].links):nt.links.new(l.from_socket,new.inputs[newindex])
  for l in list(old.outputs[0].links):nt.links.new(new.outputs[2],l.to_socket)
  nt.nodes.remove(old)
chars={s:(bpy.data.objects[s+'_Rig'],bpy.data.objects[s+'_custom_topology']) for s in ['female','male']}
C={n:bpy.data.collections[n] for n in ['Room','Characters','City','Occlusion','Studio','ModuleLibrary']}
modules=list(C['ModuleLibrary'].objects)
s=(P/'blender_scripts/build_sample.py').read_text();exec(s[s.index('# Save stand-alone GLBs,'):])
