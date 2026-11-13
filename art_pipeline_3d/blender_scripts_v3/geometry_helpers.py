import bpy,math
from math import sin,cos,pi
from mathutils import Vector
def link(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 C[CURRENT].objects.link(o);return o
def mesh(name,verts,faces,mat,uv=None,smooth=True):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);C[CURRENT].objects.link(o)
 if mat:me.materials.append(mat)
 if uv:
  layer=me.uv_layers.new()
  for poly in me.polygons:
   for li in poly.loop_indices:layer.data[li].uv=uv[me.loops[li].vertex_index]
 else:
  # Box projection in metre units: true texture density, no generated coords.
  layer=me.uv_layers.new()
  for face in me.polygons:
   axis=max(range(3),key=lambda i:abs(face.normal[i]));axes=[i for i in range(3) if i!=axis]
   for li in face.loop_indices:
    co=me.vertices[me.loops[li].vertex_index].co;layer.data[li].uv=(co[axes[0]],co[axes[1]])
 if uv:
  for face in me.polygons:
   if len(face.vertices)>4:continue
   us=[layer.data[li].uv.x for li in face.loop_indices]
   if max(us)-min(us)>.5:
    for li in face.loop_indices:
     if layer.data[li].uv.x<.5:layer.data[li].uv.x+=1
 for f in me.polygons:f.use_smooth=smooth
 return o
def bevel(o,w=.02,segments=2):
 mod=o.modifiers.new('Manufactured edge radius','BEVEL');mod.width=w;mod.segments=segments
 mod=o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL');return o
def box(name,loc,size,mat,b=.01):
 x,y,z=[v/2 for v in size];v=[(-x,-y,-z),(-x,-y,z),(-x,y,-z),(-x,y,z),(x,-y,-z),(x,-y,z),(x,y,-z),(x,y,z)];f=[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)]
 o=mesh(name,v,[tuple(reversed(face)) for face in f],mat,smooth=False);o.location=loc
 if b:bevel(o,b)
 return o
def ell(name,loc,scale,mat,seg=16,rings=8):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,location=loc);o=link(bpy.context.object);o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 for f in o.data.polygons:f.use_smooth=True
 return o
def rod(name,a,b,r,mat,verts=12):
 a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=r,depth=(b-a).length,location=(a+b)/2);o=link(bpy.context.object);o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
 for f in o.data.polygons:f.use_smooth=True
 return o
def text(name,body,loc,size,mat,rot=(pi/2,0,0)):
 curve=bpy.data.curves.new(name,'FONT');curve.body=body;curve.align_x='CENTER';curve.size=size;curve.extrude=.001;o=bpy.data.objects.new(name,curve);C[CURRENT].objects.link(o);o.location=loc;o.rotation_euler=rot;o.data.materials.append(mat);return o
def applymods(o):
 bpy.context.view_layer.objects.active=o;o.select_set(True)
 for m in list(o.modifiers):
  if m.type!='ARMATURE':bpy.ops.object.modifier_apply(modifier=m.name)
 o.select_set(False)
def join(obs,name):
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True);applymods(o)
 bpy.context.view_layer.objects.active=obs[0]
 for o in obs:o.select_set(True)
 bpy.ops.object.join();o=bpy.context.object;o.name=name;return o
