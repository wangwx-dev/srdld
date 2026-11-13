from pathlib import Path
P=Path(__file__).resolve().parent
p=P/'build_sample.py';s=p.read_text()
# Regional proportional remap used identically for mesh, bind skeleton and pose targets.
insert='''
def stylize(co):
 x,y,z=co
 if z<=.95: zz=z; xx=x*1.06; yy=y
 elif z<1.49:
  zz=.95+(z-.95)*(.39/.54)
  shoulder=math.exp(-((z-1.40)/.13)**2)
  xx=x*(1.12-.28*shoulder);yy=y*(1.04 if abs(x)<.2 else 1)
 else:zz=1.34+(z-1.49)*1.075;xx=x*1.39;yy=y*1.28
 return Vector((xx,yy,zz))
'''
s=s.replace("CURRENT='Characters';chars={};rigdata={}","CURRENT='Characters';chars={};rigdata={}\n"+insert)
s=s.replace("(1.03,.133,.095,0),(1.12,.14,.098,0)","(1.03,.148,.103,0),(1.12,.154,.103,0)")
s=s.replace("(1.4,.205 if fem else .22,.09,0),(1.445,.145,.075,0)","(1.38,.182 if fem else .195,.095,0),(1.445,.112,.071,0)")
s=s.replace('v=[];uv=[];f=[];N=12;wr=[]','v=[];uv=[];f=[];N=10;wr=[]')
start=s.index(' if fem:\n  # back and two tapered')
end=s.index(' # Nose tip',start)
s=s[:start]+''' # Rounded overlapping locks form a sculpted side-swept hairstyle, no flat hair cards.
 for k in range(5):
  x=-.084+k*.041
  ob=ell('Swept fringe lock',(x,-.084,1.728+.016*cos(k)),(.043,.041,.065-.005*k),M['hairlight'] if k==2 else M['hair'],10,6)
  ob.rotation_euler.y=-.3;weights(ob,rigid('Head'))
 for side in [-1,1]:
  weights(ell('Temple tapered lock',(side*.116,.012,1.667),(.024,.055,.072 if fem else .045),M['hair'],10,6),rigid('Head'))
 if fem:
  weights(ell('Ponytail tied crown',(0,.112,1.742),(.065,.075,.066),M['hair'],12,6),rigid('Head'))
  weights(ell('Ponytail cascading volume',(.018,.145,1.624),(.067,.064,.126),M['hair'],12,6),rigid('Head'))
''' + s[end:]
# reduce finger budget, cleaner shoe shape
s=s.replace('for fi in range(4):','for fi in range(3):')
s=s.replace("(.072,.16,.075)","(.068,.137,.075)")
a=s.index("  o=box('Sneaker sole'");b=s.index(' # Fuse tailored',a)
s=s[:a]+'''  o=ell('Rounded rubber cupsole',(s*.12,-.065,.031),(.074,.148,.026),M['white'],12,6);weights(o,rigid(side+'Foot'))
  o=ell('Sneaker heel counter',(s*.12,.042,.084),(.069,.042,.055),shirt,10,6);weights(o,rigid(side+'Foot'))
  o=ell('Sneaker tongue',(s*.12,-.035,.135),(.034,.065,.017),M['white'],10,4);weights(o,rigid(side+'Foot'))
  for yy in [-.08,-.045,-.01]:
   o=rod('Fine cotton laces',(s*.12-.028,yy,.15),(s*.12+.028,yy,.15),.003,M['linen'],6);weights(o,rigid(side+'Foot'))
''' + s[b:]
# fuse trousers for round crotch, analytical normalized hip/knee weighting.
a=s.index(' body=join(parts,');s=s[:a]+''' # V2 continuous hip-to-trouser shell removes intersecting capped hip/leg seams.
 trouser_parts=[o for o in parts if o.name.startswith(sex+'_pelvis_bridge') or o.name.startswith('Trouser continuous leg')]
 for o in trouser_parts:parts.remove(o)
 trousers=join(trouser_parts,sex+'_seamless_trousers')
 bpy.context.view_layer.objects.active=trousers
 rem=trousers.modifiers.new('Continuous soft crotch','REMESH');rem.mode='VOXEL';rem.voxel_size=.012;bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=trousers.modifiers.new('Relax seam curvature','SMOOTH');sm.factor=1;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
 trousers.data.calc_loop_triangles();d=trousers.modifiers.new('Trouser budget','DECIMATE');d.ratio=min(1,650/len(trousers.data.loop_triangles));bpy.ops.object.modifier_apply(modifier=d.name)
 trousers.vertex_groups.clear()
 for poly in trousers.data.polygons:poly.use_smooth=True
 def pantsweights(co):
  side='Left' if co.x>0 else 'Right'
  if co.z>.89:return {'Hips':1}
  if co.z>.76:t=(co.z-.76)/.13;return {'Hips':t,side+'UpLeg':1-t}
  if co.z>.44 and co.z<.56:t=(co.z-.44)/.12;return {side+'UpLeg':t,side+'Leg':1-t}
  return {side+('UpLeg' if co.z>=.56 else 'Leg'):1}
 weights(trousers,pantsweights)
''' +s[a:]
# Map vertex coordinates after joining baked objects, then clean degenerates/repeated indices.
s=s.replace(" # Store manual refined weights",''' for v in body.data.vertices:v.co=stylize(v.co)
 import bmesh
 bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.dissolve_degenerate(bm,dist=.000001,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
 bone_specs={n:(stylize(h),stylize(t),par) for n,(h,t,par) in bone_specs.items()}
 # Store manual refined weights''')
# Targets map in world joint space: fixed contact heights retained, shorten shoulder span and enlarge head bone.
s=s.replace(" h,t=pos[pb.name];rest=", " h,t=pos[pb.name];h=stylize(h);t=stylize(t);rest=")
# back chair lower and rearward; shelf left foreground unobscured; trim low wall intersection.
s=s.replace("(.55,1.55,.85),(.54,.08,.58)","(.55,1.48,.78),(.50,.08,.46)")
s=s.replace("# Carpet, cat bed",'''# Shift complete bookcase toward open west wall, avoiding bed headboard occlusion.
for obj in C['Room'].objects:
 if obj.name.startswith(('Bookshelf','Book cloth spine','Book pages')):obj.location.y-=2.75
# Unique front-left instance: trim 20 cm corner overlap without moving its origin.
for obj in list(C['Room'].objects):
 if obj.name.startswith('wall_low_front') and abs(obj.location.x+4)<.01:
  obj.data=obj.data.copy()
  for v in obj.data.vertices:
   if v.co.x<.201:v.co.x=.201
# Carpet, cat bed''')
s=s.replace("ld.energy=1100;ld.size=6;ld.color=(1,.84,.66)","ld.energy=1800;ld.size=7;ld.color=(1,.88,.73)")
s=s.replace('ld.energy=1.5;ld.angle=.16','ld.energy=2.0;ld.angle=.24')
# add warm broad fill and exposure
s=s.replace("camd=bpy.data.cameras.new",'''ld=bpy.data.lights.new('Interior warm bounce','AREA');lo=bpy.data.objects.new('Interior warm bounce',ld);C['Studio'].objects.link(lo);lo.location=(2,-1,5);ld.energy=750;ld.size=5;ld.color=(1,.87,.72);lo.rotation_euler=(Vector((-1,1,.7))-lo.location).to_track_quat('-Z','Y').to_euler()
sc.view_settings.exposure=.35
camd=bpy.data.cameras.new''')
p.write_text(s)
# render pose utility must use same coordinate transform
p=P/'pose_utils.py';t=p.read_text();t=t.replace('def pose(arm,kind):',insert+'\ndef pose(arm,kind):');t=t.replace('h,t=pos[pb.name];rest=', 'h,t=pos[pb.name];h=stylize(h);t=stylize(t);rest=');p.write_text(t)
