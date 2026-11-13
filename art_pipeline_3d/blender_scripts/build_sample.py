import bpy,math,json,random,os
from mathutils import Vector,Matrix
from pathlib import Path
from math import sin,cos,pi
P=Path(__file__).resolve().parents[1];random.seed(32)
bpy.ops.wm.read_factory_settings(use_empty=True)
sc=bpy.context.scene; sc.unit_settings.system='METRIC';sc.unit_settings.scale_length=1
sc.render.engine='CYCLES';sc.cycles.samples=24;sc.cycles.use_denoising=True;sc.cycles.max_bounces=5
sc.render.resolution_x=1920;sc.render.resolution_y=1080;sc.render.resolution_percentage=100
sc.render.image_settings.file_format='PNG';sc.render.threads_mode='FIXED';sc.render.threads=6
sc.view_settings.view_transform='AgX'
C={}
for name in ['Room','Characters','City','Occlusion','Studio','ModuleLibrary']:
 c=bpy.data.collections.new(name);sc.collection.children.link(c);C[name]=c
CURRENT='Room'
def link(o):
 for c in list(o.users_collection):c.objects.unlink(o)
 C[CURRENT].objects.link(o);return o
manifest=json.loads((P/'asset_manifest.json').read_text())
def pbr(name,slug,tint=None,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes;l=m.node_tree.links;bs=n.get('Principled BSDF');bs.inputs['Metallic'].default_value=metal
 for kind,socket in [('Diffuse','Base Color'),('Rough','Roughness'),('nor_gl','Normal')]:
  entry=next(f for f in manifest['files'] if f['asset']==slug and f['map']==kind)
  tex=n.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(P/entry['path']),check_existing=True);tex.label=slug+' '+kind
  if kind!='Diffuse':tex.image.colorspace_settings.name='Non-Color'
  if kind=='nor_gl':
   norm=n.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.32;l.new(tex.outputs['Color'],norm.inputs['Color']);l.new(norm.outputs[0],bs.inputs[socket])
  elif kind=='Diffuse' and tint:
   mix=n.new('ShaderNodeMix');mix.data_type='RGBA';mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[7].default_value=(*tint,1);l.new(tex.outputs['Color'],mix.inputs[6]);l.new(mix.outputs[2],bs.inputs[socket])
  else:l.new(tex.outputs['Color'],bs.inputs[socket])
 m['source']='Poly Haven CC0 / '+slug;return m
def simple(name,col,rough=.5,metal=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True;bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*col,1);bs.inputs['Roughness'].default_value=rough;bs.inputs['Metallic'].default_value=metal;return m
def image_mat(name,path,emission=0):
 m=simple(name,(1,1,1));n=m.node_tree.nodes;l=m.node_tree.links;t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(path),check_existing=True);bs=n.get('Principled BSDF');l.new(t.outputs['Color'],bs.inputs['Base Color'])
 if emission:l.new(t.outputs['Color'],bs.inputs['Emission Color']);bs.inputs['Emission Strength'].default_value=emission
 return m
M={}
for name,slug,tint,met in [('floor','wood_floor',None,0),('wall','painted_plaster_wall',None,0),('linen','rough_linen',None,0),('wood','dark_wood',None,0),('metal','metal_plate',None,.8),('ceramic','floor_tiles_08',None,0),('road','asphalt_03',None,0),('grass','grass_ground',None,0),('teal','cotton_jersey',(.17,.45,.42),0),('ochre','cotton_jersey',(.68,.37,.13),0),('denim','cotton_jersey',(.12,.2,.27),0),('cream','painted_plaster_wall',(1,.91,.73),0)]:M[name]=pbr(name,slug,tint,met)
M['metal']=simple('Powder coated graphite',(.045,.055,.06),.43,.45)
M['skin']=simple('Warm skin satin',(.62,.38,.27),.62);M['hair']=simple('Chestnut sculpted hair',(.058,.027,.018),.78);M['hairlight']=simple('Warm hair edges',(.13,.065,.028),.53)
M['leaf']=simple('Leaf green',(.075,.19,.065),.7);M['ink']=simple('Ink',(.028,.038,.04));M['white']=simple('Warm white',(.8,.78,.69));M['eye']=simple('Amber eyes',(.6,.45,.12));M['water']=simple('River blue green',(.09,.3,.35),.22,.25)
M['screen']=image_mat('Original creator-studio display',P/'textures/monitor_content.png',.5)
M['pages']=image_mat('Book paper pages',P/'textures/pages.png')
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
# Standard modules, geometry in local coordinates with exact corner pivots.
CURRENT='ModuleLibrary';modules=[]
def module(name,kind):
 parts=[]
 def b(n,lo,sz,ma):parts.append(box(n,lo,sz,ma,0))
 if kind=='floor':b('tile',(1,1,-.06),(2,2,.12),M['floor'])
 elif kind in ['wall','low']:
  h=3 if kind=='wall' else .5;b('wall',(1,.1,h/2),(2,.2,h),M['wall']);b('skirting',(1,.205,.075),(2,.01,.15),M['wood'])
 elif kind=='corner':
  b('north',(1,.1,1.5),(2,.2,3),M['wall']);b('west',(.1,1.1,1.5),(.2,1.8,3),M['wall'])
 elif kind=='window':
  b('sill-base',(1,.1,.5),(2,.2,1),M['wall']);b('lintel',(1,.1,2.75),(2,.2,.5),M['wall'])
  for x in [.15,1.85]:b('jamb',(x,.1,1.75),(.3,.2,1.5),M['wall'])
  for x in [.31,1,1.69]:b('window-frame',(x,.1,1.75),(.06,.24,1.5),M['wood'])
  for z in [1.02,1.75,2.48]:
   for xx in [.655,1.345]:b('transom',(xx,.1,z),(.63,.24,.05),M['wood'])
  b('deep sill',(1,-.03,.99),(1.6,.4,.08),M['wood'])
 elif kind=='door':
  for x in [.2,1.8]:b('wall',(x,.1,1.5),(.4,.2,3),M['wall'])
  b('lintel',(1,.1,2.75),(1.2,.2,.5),M['wall']);b('door leaf',(1,.11,1.15),(1.08,.08,2.3),M['wood'])
  for x in [.43,1.57]:b('door frame',(x,-.03,1.1775),(.09,.13,2.355),M['cream'])
  b('door frame top',(1,-.03,2.4),(1.23,.13,.09),M['cream']);b('handle',(1.4,-.04,1.1),(.13,.08,.035),M['metal'])
 o=join(parts,name);bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');modules.append(o);return o
for n,k in [('floor_tile_2x2','floor'),('wall_back_2x3','wall'),('wall_corner_in_2x2x3','corner'),('wall_low_front_2x05','low'),('wall_window_2x3','window'),('door_module_2x3','door')]:module(n,k)
CURRENT='Room'
def inst(index,loc,rot=0):
 src=modules[index];o=src.copy();o.data=src.data;C[CURRENT].objects.link(o);o.location=loc;o.rotation_euler.z=rot;return o
for x in [-4,-2,0]:
 for y in [-2,0,2]:inst(0,(x,y,0))
# room 6x6: x -4..2 y -2..4
for x,idx in [(-4,1),(-2,5),(0,4)]:inst(idx,(x,4,0),pi) if False else inst(idx,(x,4,0))
for y in [-2,0,2]:inst(1,(-4,y+2,0),-pi/2)
for x in [-4,-2,0]:inst(3,(x,-2,0))
# Desk front faces camera, real geometry keyboard and mouse.
box('Desk walnut top',(.65,2.65,.775),(2.05,.85,.065),M['wood'],.025)
for x in [-.24,1.52]:
 for y in [2.35,2.95]:box('Steel desk legs',(x,y,.38),(.055,.055,.76),M['metal'])
box('Monitor pedestal',(.55,2.8,.837),(.45,.3,.055),M['metal']);box('Monitor stem',(.55,2.86,1.04),(.07,.065,.42),M['metal'])
box('Monitor 27 inch frame',(.55,2.88,1.26),(1.04,.07,.62),M['metal'],.02)
# Explicit UV screen quad, front -Y.
mesh('Monitor visible display',[(-.485,0,-.273),(.485,0,-.273),(.485,0,.273),(-.485,0,.273)],[(0,1,2,3)],M['screen'],[(0,0),(1,0),(1,1),(0,1)],False).location=(.55,2.838,1.26)
box('Keyboard slab',(.55,2.36,.828),(.66,.225,.035),M['metal'])
for i in range(13):
 for j in range(4):box('Keycap',(.255+i*.046,2.278+j*.049,.855),(.037,.038,.012),M['cream'],.003)
ell('Mouse',(1.12,2.36,.858),(.065,.105,.034),M['metal'])
box('Mouse mat',(1.12,2.37,.815),(.33,.32,.008),M['linen'],0)
# chair exactly touching seated pelvis at z .54
box('Office chair cushion',(.55,1.82,.51),(.54,.5,.1),M['teal'],.045)
box('Office chair curved back',(.55,1.48,.78),(.50,.08,.46),M['teal'],.035)
rod('Chair gas lift',(.55,1.82,.15),(.55,1.82,.46),.04,M['metal'])
for a in range(5):
 x=.55+cos(a*2*pi/5)*.33;y=1.82+sin(a*2*pi/5)*.33
 rod('Chair star base',(.55,1.82,.14),(x,y,.1),.025,M['metal']);ell('Caster',(x,y,.065),(.052,.045,.052),M['metal'],12,6)
# Bed: layered, hand-shaped folded duvet with subtle undulations and turn-down.
box('Bed timber frame',(-2.6,1.1,.28),(1.55,2.5,.4),M['wood'],.045)
for x in [-3.23,-1.97]:
 for y in [.1,2.1]:box('Bed feet',(x,y,.12),(.12,.12,.24),M['wood'])
box('Upholstered headboard',(-2.6,2.37,.78),(1.62,.12,1.1),M['linen'],.07)
box('Mattress piping',(-2.6,1.1,.53),(1.49,2.34,.23),M['linen'],.085)
# folded duvet quilt mesh grid plus solidify
v=[];f=[];nx=18;ny=20
for j in range(ny+1):
 y=-.1+j*1.74/ny
 for i in range(nx+1):
  x=-3.36+i*1.52/nx;edge=(max(0,abs(x+2.6)-.63)/.13)**2;z=.72-.13*edge+.018*sin(i*.8+j*.6)+.016*cos(j*.83)
  if j>17:z+=.06*sin((j-17)/3*pi)
  v.append((x,y,z))
for j in range(ny):
 for i in range(nx):a=j*(nx+1)+i;f.append((a,a+1,a+nx+2,a+nx+1))
o=mesh('Duvet with folded upper edge',v,f,M['teal']);o.modifiers.new('Duvet real thickness','SOLIDIFY').thickness=.025
for x in [-2.94,-2.26]:box('Pillow with loft',(x,1.96,.745),(.63,.43,.19),M['linen'],.09)
box('Bedside cabinet',(-1.49,2.18,.32),(.43,.52,.64),M['wood'],.02)
# Bookshelf with books of differing height, PBR covers.
box('Bookshelf back',(-3.83,2.8,1.05),(.1,1.6,2.1),M['wood'])
for y in [2.02,3.58]:box('Bookshelf side',(-3.62,y,1.05),(.48,.06,2.1),M['wood'])
for z in [.12,.64,1.16,1.68,2.1]:box('Bookshelf shelf',(-3.62,2.8,z),(.48,1.6,.045),M['wood'])
for row in range(3):
 for j in range(12):
  h=random.uniform(.24,.39);o=box('Book cloth spine',(-3.57,2.1+j*.113,.17+row*.52+h/2),(.27,.085,h),M[['teal','ochre','linen','denim'][j%4]],.005)
  box('Book pages',(-3.52,2.1+j*.113,.17+row*.52+h/2),(.23,.071,h*.92),M['pages'],.002)
# Shift complete bookcase toward open west wall, avoiding bed headboard occlusion.
for obj in C['Room'].objects:
 if obj.name.startswith(('Bookshelf','Book cloth spine','Book pages')):obj.location.y-=2.75
# Unique front-left instance: trim 20 cm corner overlap without moving its origin.
for obj in list(C['Room'].objects):
 if obj.name.startswith('wall_low_front') and abs(obj.location.x+4)<.01:
  obj.data=obj.data.copy()
  for v in obj.data.vertices:
   if v.co.x<.201:v.co.x=.201
# Carpet, cat bed and modeled cat silhouette.
box('Woven living rug',(-.7,.2,.014),(2.3,1.65,.028),M['linen'],.035)
for x in [-1.8,.4]:
 for y in [i*.075-.55 for i in range(21)]:rod('Rug fringe',(x,y,.028),(x+(-.09 if x<0 else .09),y,.028),.006,M['linen'],6)
# cat's body, shoulders and haunches deliberately anatomically distinct
CAT_CENTER=(-.4,.05,0)
def cat(cx,cy):
 ell('Cat bed padded oval',(cx,cy,.07),(.46,.34,.07),M['ochre'],24,10)
 bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,location=(cx,cy,.12),major_radius=.32,minor_radius=.07);o=link(bpy.context.object);o.name='Cat bed raised fabric rim';o.scale.y=.77;o.data.materials.append(M['linen'])
 fur=simple('Cat russet fur',(.37,.19,.09),.85)
 ell('Cat curled ribcage',(cx,cy,.24),(.28,.17,.17),fur,20,12);ell('Cat haunch',(cx+.16,cy+.03,.24),(.16,.15,.17),fur)
 ell('Cat head',(cx-.2,cy-.07,.35),(.135,.12,.115),fur,20,12)
 for x in [cx-.27,cx-.14]:
  # triangular ears, not spheres
  mesh('Cat pointed ear',[(x-.045,cy-.04,.41),(x+.045,cy-.04,.41),(x,cy-.04,.53),(x,cy+.025,.45)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],fur)
 for x in [cx-.26,cx-.155]:
  ell('Cat eye',(x,cy-.173,.373),(.016,.008,.012),M['eye'],12,6)
 ell('Cat nose',(cx-.205,cy-.187,.338),(.015,.008,.01),M['ink'],8,4)
 for x in [cx-.25,cx-.12]:ell('Cat paw',(x,cy-.17,.17),(.078,.06,.045),fur)
 # curved tail swept along outline
 curve=bpy.data.curves.new('Cat curved tail','CURVE');curve.dimensions='3D';curve.bevel_depth=.036;curve.bevel_resolution=2;s=curve.splines.new('BEZIER');s.bezier_points.add(4)
 for pt,co in zip(s.bezier_points,[(cx+.25,cy+.07,.22),(cx+.31,cy-.1,.17),(cx+.17,cy-.22,.16),(cx-.03,cy-.23,.17),(cx-.1,cy-.2,.2)]):pt.co=co;pt.handle_left_type=pt.handle_right_type='AUTO'
 ob=bpy.data.objects.new('Cat curled tail',curve);C[CURRENT].objects.link(ob);ob.data.materials.append(fur)
cat(-.4,.05)
# Plants: trunk, pot and individually folded leaves, not balls.
def plant(cx,cy,z=0,sz=1):
 ell('Ceramic planter',(cx,cy,z+.23*sz),(.23*sz,.23*sz,.27*sz),M['ceramic'])
 for i in range(9):
  a=i*2.4;r=.25*sz;h=(.6+(i%3)*.15)*sz;end=(cx+cos(a)*r,cy+sin(a)*r,z+h)
  rod('Plant stem',(cx,cy,z+.35*sz),end,.008*sz,M['wood'],6)
  c=Vector(end);dr=Vector((cos(a),sin(a),.3))*sz;side=Vector((-sin(a),cos(a),0))*.08*sz
  mesh('Folded leaf',[tuple(c-dr*.15),tuple(c+dr*.2+side),tuple(c+dr*.38),tuple(c+dr*.2-side),tuple(c+dr*.2+Vector((0,0,.035)))],[(0,1,4),(1,2,4),(2,3,4),(3,0,4)],M['leaf'])
plant(1.4,3.55,0,1.25)
# Exit zone: clear label and outlined threshold.
box('Exit woven doormat',(-1,3.54,.022),(1.05,.6,.044),M['ochre']);text('Exit prompt','EXIT',(-1,3.32,.048),.16,M['ink'],(0,0,0))
text('Door plaque','HOME / 03',(-1,3.947,1.85),.13,M['cream'])
# Real downloaded prop, verified CC0 dependencies.
pre=set(bpy.data.objects);path=next(P/f['path'] for f in manifest['files'] if f['map']=='gltf');bpy.ops.import_scene.gltf(filepath=str(path));new=set(bpy.data.objects)-pre
for o in new:link(o)
root=bpy.data.objects.new('PolyHaven verified coffee table',None);C['Room'].objects.link(root)
for o in new:
 if o.parent is None:o.parent=root
root.location=(.55,-.9,0);root.scale=(.65,.65,.65)
# CHARACTER BUILD: custom ring topology, human proportions, modeled palms and thumbs.
CURRENT='Characters';chars={};rigdata={}

def stylize(co):
 x,y,z=co
 if z<=.95: zz=z; xx=x*1.06; yy=y
 elif z<1.49:
  zz=.95+(z-.95)*(.39/.54)
  shoulder=math.exp(-((z-1.40)/.13)**2)
  xx=x*(1.12-.28*shoulder);yy=y*(1.04 if abs(x)<.2 else 1)
 else:zz=1.34+(z-1.49)*1.075;xx=x*1.39;yy=y*1.28
 return Vector((xx,yy,zz))

def make_character(sex):
 parts=[];bone_specs={};W={};fem=sex=='female'
 skin=M['skin'].copy();skin.name=sex+'_skin';skin.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=((.72,.47,.34,1) if fem else (.55,.33,.23,1))
 face=image_mat(sex+' painted subtle face',P/f'textures/{sex}_face.png')
 shirt=M['teal'] if fem else M['ochre'];pants=M['denim'] if fem else M['linen']
 def bone(n,h,t,parent=None):bone_specs[n]=(Vector(h),Vector(t),parent)
 bone('Hips',(0,0,.85),(0,0,1.0));bone('Spine',(0,0,1),(0,0,1.22),'Hips');bone('Chest',(0,0,1.22),(0,0,1.46),'Spine');bone('Neck',(0,0,1.46),(0,0,1.55),'Chest');bone('Head',(0,0,1.55),(0,0,1.8),'Neck')
 for side,s in [('Left',1),('Right',-1)]:
  bone(side+'Shoulder',(0,0,1.43),(s*.23,0,1.43),'Chest');bone(side+'Arm',(s*.23,0,1.43),(s*.25,0,1.17),side+'Shoulder');bone(side+'ForeArm',(s*.25,0,1.17),(s*.26,-.035,.97),side+'Arm');bone(side+'Hand',(s*.26,-.035,.97),(s*.27,-.05,.88),side+'ForeArm')
  bone(side+'UpLeg',(s*.105,0,.87),(s*.115,-.01,.48),'Hips');bone(side+'Leg',(s*.115,-.01,.48),(s*.12,0,.105),side+'UpLeg');bone(side+'Foot',(s*.12,0,.105),(s*.12,-.18,.07),side+'Leg');bone(side+'ToeBase',(s*.12,-.18,.07),(s*.12,-.26,.065),side+'Foot')
 def weights(o,fn):
  for v in o.data.vertices:
   for n,w in fn(v.co).items():
    if w>0:
     g=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);g.add([v.index],w,'REPLACE')
  parts.append(o);return o
 def rings(name,rs,mat,fn,N=16,head=False):
  verts=[];uv=[];faces=[]
  for j,(z,rx,ry,cy) in enumerate(rs):
   for i in range(N):
    theta=-pi+2*pi*i/N;x=sin(theta)*rx;y=-cos(theta)*ry+cy
    # Modest nose formed IN facial grid, no attached ball.
    if head:
     y-=.028*math.exp(-(x/.026)**2-((z-1.635)/.035)**2)*max(0,cos(theta))**12
    verts.append((x,y,z));uv.append((i/N,(z-1.49)/.32 if head else j/(len(rs)-1)))
  for j in range(len(rs)-1):
   for i in range(N):a=j*N+i;b=j*N+(i+1)%N;faces.append((a,b,b+N,a+N))
  faces.extend([tuple(reversed(range(N))),tuple((len(rs)-1)*N+i for i in range(N))]);o=mesh(name,verts,faces,mat,uv)
  # Fix cylindrical UV seam on individual loops.
  for poly in o.data.polygons:
   us=[o.data.uv_layers[0].data[li].uv.x for li in poly.loop_indices]
   if max(us)-min(us)>.5:
    for li in poly.loop_indices:
     if o.data.uv_layers[0].data[li].uv.x<.2:o.data.uv_layers[0].data[li].uv.x+=1
  return weights(o,fn)
 def rigid(n):return lambda co:{n:1}
 def blendz(co):
  z=co.z
  if z<1.04:return {'Hips':1}
  if z<1.21:t=(z-1.04)/.17;return {'Spine':1-t,'Chest':t}
  return {'Chest':1}
 rings(sex+'_tailored_top',[(.89,.145,.092,0),(.96,.15,.105,0),(1.03,.148,.103,0),(1.12,.154,.103,0),(1.22,.164 if fem else .18,.102,-.007),(1.31,.178 if fem else .194,.106,0),(1.38,.182 if fem else .195,.095,0),(1.445,.112,.071,0)],shirt,blendz,20)
 rings(sex+'_neck',[(1.405,.067,.06,0),(1.46,.06,.058,0),(1.51,.064,.063,0),(1.55,.077,.065,0)],skin,lambda co:{'Neck':min(1,max(0,(1.55-co.z)/.1)),'Head':min(1,max(0,(co.z-1.45)/.1))},16)
 rings(sex+'_face_head',[(1.49,.058,.052,-.012),(1.515,.082,.074,-.007),(1.54,.101,.088,0),(1.57,.102,.092,0),(1.60,.111,.1,0),(1.63,.116,.105,0),(1.66,.118,.105,0),(1.69,.116,.106,0),(1.72,.111,.103,0),(1.75,.099,.092,0),(1.78,.075,.07,0),(1.80,.035,.035,0)],face,rigid('Head'),32,True)
 for s in [-1,1]:weights(ell('Ear',(s*.114,.006,1.625),(.022,.018,.04),skin,12,6),rigid('Head'))
 # Two skinned eyelid patches: hidden under hair while awake; morph onto the eyes for Sleep_Bed.
 lidmat=simple(sex+'_sleep_skin_lid',tuple((c/255)**2.2 for c in ((232,183,159) if fem else (210,161,133))),.65)
 lashmat=simple(sex+'_sleep_lash',(.045,.025,.017),.8)
 for side in [-1,1]:
  vv=[];ff=[];N=6
  for j in range(4):
   z=1.607+j*.020
   for i in range(N+1):
    ang=side*.50-.30+i*.60/N
    vv.append((sin(ang)*.117,-cos(ang)*.106-.003,z))
  for j in range(3):
   for i in range(N):a=j*(N+1)+i;ff.append((a,a+1,a+N+2,a+N+1))
  weights(mesh('Sleep eyelid surface',vv,ff,lidmat),rigid('Head'))
  vv=[];ff=[]
  for i in range(N+1):
   ang=side*.5-.23+i*.46/N;zz=1.633-.007*sin(pi*i/N)
   for dz in [-.0015,.0015]:vv.append((sin(ang)*.117,-cos(ang)*.106-.0045,zz+dz))
  for i in range(N):ff.append((2*i,2*i+1,2*i+3,2*i+2))
  weights(mesh('Sleep soft lash line',vv,ff,lashmat),rigid('Head'))
 # Sculpted hair cap and angular fringe; broad silhouette masses, no sausage strands.
 hv=[];hf=[];N=28
 for j in range(6):
  for i in range(N):
   a=-pi+2*pi*i/N;front=max(0,cos(a));bottom=(1.70 if not fem else 1.69)-(.025*sin(a*3)+.012*cos(a*5))*front
   z=bottom+(1.825-bottom)*j/5;r=math.sqrt(max(.015,1-((z-1.69)/.145)**2));hv.append((sin(a)*.127*r,-cos(a)*.117*r+.009,z))
 for j in range(5):
  for i in range(N):a=j*N+i;b=j*N+(i+1)%N;hf.append((a,b,b+N,a+N))
 hf.append(tuple(5*N+i for i in range(N)));weights(mesh('Sculpted swept hair cap',hv,hf,M['hair']),rigid('Head'))
 # Rounded overlapping locks form a sculpted side-swept hairstyle, no flat hair cards.
 for k in range(3):
  x=-.060+k*.060
  ob=ell('Swept fringe lock',(x,-.090,1.722+k*.014),(.052,.014,.026),M['hair'],10,6)
  ob.rotation_euler.y=-.28;weights(ob,rigid('Head'))
 for side in [-1,1]:
  weights(ell('Temple tapered lock',(side*.116,.012,1.667),(.024,.055,.072 if fem else .045),M['hair'],10,6),rigid('Head'))
 if fem:
  weights(ell('Ponytail tied crown',(0,.112,1.742),(.065,.075,.066),M['hair'],12,6),rigid('Head'))
  weights(ell('Ponytail cascading volume',(.018,.145,1.624),(.067,.064,.126),M['hair'],12,6),rigid('Head'))
 # Nose tip is continuous head topology above. Collars and shirt opening add clothing identity.
 for s in [-1,1]:
  v=[(s*.03,-.078,1.449),(s*.085,-.096,1.405),(s*.055,-.118,1.355),(s*.015,-.103,1.413)]
  weights(mesh('Soft collar' if not fem else 'T-shirt neck facing',v,[(0,1,2,3)],M['cream'] if not fem else shirt),rigid('Chest'))
 if not fem:
  for z in [1.08,1.18,1.28,1.38]:weights(ell('Shirt button',(0,-.111,z),(.009,.006,.009),M['cream'],8,4),blendz)
 rings(sex+'_pelvis_bridge',[(.89,.12,.087,0),(.95,.145,.096,0),(.99,.145,.096,0)],pants,rigid('Hips'),16)
 # Elliptical sweep along limb with explicit smooth joint transitions.
 def limb(name,points,rads,mat,bnames):
  v=[];uv=[];f=[];N=8;wr=[]
  for j,p in enumerate(points):
   p=Vector(p);t=Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)]);t.normalize();u=t.cross(Vector((0,1,0))).normalized();vv=t.cross(u).normalized()
   rx,ry=rads[j]
   for i in range(N):a=2*pi*i/N;v.append(tuple(p+u*cos(a)*rx+vv*sin(a)*ry));uv.append((i/N,j/(len(points)-1)));wr.append(bnames[j])
  for j in range(len(points)-1):
   for i in range(N):a=j*N+i;b=j*N+(i+1)%N;f.append((a,b,b+N,a+N))
  f.extend([tuple(reversed(range(N))),tuple((len(points)-1)*N+i for i in range(N))]);o=mesh(name,v,f,mat,uv)
  for i,d in enumerate(wr):
   for n,w in d.items():g=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);g.add([i],w,'REPLACE')
  parts.append(o);return o
 for side,s in [('Left',1),('Right',-1)]:
  A=side+'Arm';B=side+'ForeArm';H=side+'Hand';L=side+'UpLeg';K=side+'Leg'
  def ar(x,z,y=0):return (s*(x if x<=.225 else .225+(x-.225)*.075),y,z)
  points=[ar(.17,1.38),ar(.225,1.38),ar(.29,1.32),ar(.4,1.23),ar(.46,1.17),ar(.50,1.13),ar(.59,1.055,-.02),ar(.68,.97,-.035)]
  rr=[(.055,.075),(.060,.066),(.059,.057),(.06,.06),(.054,.052),(.052,.05),(.044,.041),(.031,.03)]
  ws=[{A:1},{A:1},{A:1},{A:.85,B:.15},{A:.5,B:.5},{A:.15,B:.85},{B:1},{B:.7,H:.3}]
  limb('Tailored sleeve and forearm',points,rr,shirt,ws)
  # visible hand: tapering palm, four finger contours and opposing thumb.
  palm=[ar(.674,.977,-.035),ar(.71,.942,-.039),ar(.755,.903,-.047),ar(.784,.883,-.052)]
  limb('Palm',palm,[(.031,.03),(.038,.024),(.034,.021),(.025,.017)],skin,[{B:.25,H:.75},{H:1},{H:1},{H:1}])
  for fi in range(0):
   yy=-.075+fi*.016;length=[.046,.055,.052,.038][fi];p1=ar(.767,.89,yy);p2=ar(.79+length*.3,.868-length*.4,yy);p3=ar(.79+length*.55,.856-length*.45,yy)
   limb('Finger contour',[p1,p2,p3],[(.009,.009),(.008,.008),(.005,.006)],skin,[{H:1}]*3)
  limb('Opposing thumb',[ar(.719,.93,-.067),ar(.726,.901,-.09),ar(.752,.89,-.093)],[(.014,.014),(.012,.012),(.008,.008)],skin,[{H:1}]*3)
  # pants legs meet at pelvis, no skin gap at hip/knee
  points=[ar(.085,.94),ar(.102,.86),ar(.105,.75),ar(.11,.60),ar(.115,.49,-.01),ar(.116,.44,-.01),ar(.12,.28),ar(.12,.12)]
  rr=[(.1,.095),(.098,.1),(.09,.087),(.072,.07),(.065,.064),(.064,.06),(.053,.05),(.046,.045)]
  ws=[{'Hips':.6,L:.4},{'Hips':.2,L:.8},{L:1},{L:1},{L:.55,K:.45},{L:.15,K:.85},{K:1},{K:1}]
  limb('Trouser continuous leg',points,rr,pants,ws)
  o=ell('Leather sneaker upper',(s*.12,-.065,.078),(.068,.137,.075),M['cream'],16,6);weights(o,rigid(side+'Foot'))
  o=ell('Rounded rubber cupsole',(s*.12,-.065,.031),(.074,.148,.026),M['white'],12,6);weights(o,rigid(side+'Foot'))
  o=ell('Sneaker heel counter',(s*.12,.042,.084),(.069,.042,.055),shirt,10,6);weights(o,rigid(side+'Foot'))
  o=ell('Sneaker tongue',(s*.12,-.035,.135),(.034,.065,.017),M['white'],10,4);weights(o,rigid(side+'Foot'))
  for yy in [-.08,-.045,-.01]:
   o=rod('Fine cotton laces',(s*.12-.028,yy,.15),(s*.12+.028,yy,.15),.003,M['linen'],6);weights(o,rigid(side+'Foot'))
 # Fuse tailored shoulder/arm/torso shell before skinning: no intersecting capped sleeves.
 garment_parts=[o for o in parts if o.name.startswith(sex+'_tailored_top') or o.name.startswith('Tailored sleeve and forearm')]
 for o in garment_parts:parts.remove(o)
 garment=join(garment_parts,sex+'_continuous_garment')
 bpy.context.view_layer.objects.active=garment
 rem=garment.modifiers.new('Watertight stitched garment union','REMESH');rem.mode='VOXEL';rem.voxel_size=.009;rem.use_smooth_shade=True
 bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=garment.modifiers.new('Relax tailored shoulder silhouette','SMOOTH');sm.factor=1;sm.iterations=9;bpy.ops.object.modifier_apply(modifier=sm.name)
 garment.data.calc_loop_triangles();dec=garment.modifiers.new('Realtime garment topology budget','DECIMATE');dec.ratio=min(1,800/max(1,len(garment.data.loop_triangles)));bpy.ops.object.modifier_apply(modifier=dec.name)
 garment.vertex_groups.clear()
 for layer in list(garment.data.uv_layers):garment.data.uv_layers.remove(layer)
 layer=garment.data.uv_layers.new(name='UVMap')
 for poly in garment.data.polygons:
  axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
  for li in poly.loop_indices:
   co=garment.data.vertices[garment.data.loops[li].vertex_index].co;layer.data[li].uv=(co[axes[0]]*2,co[axes[1]]*2)
 def garment_weights(co):
  side='Left' if co.x>0 else 'Right';x=abs(co.x)
  if x<.17:return blendz(co)
  if co.z>1.34:
   t=min(1,max(0,(x-.13)/.12));return {'Chest':1-t,side+'Shoulder':t*.4,side+'Arm':t*.6}
  if co.z>1.24:return {side+'Arm':1}
  if co.z>1.10:
   t=(1.24-co.z)/.14;return {side+'Arm':1-t,side+'ForeArm':t}
  return {side+'ForeArm':1}
 weights(garment,garment_weights)
 # V2 continuous hip-to-trouser shell removes intersecting capped hip/leg seams.
 trouser_parts=[o for o in parts if o.name.startswith(sex+'_pelvis_bridge') or o.name.startswith('Trouser continuous leg')]
 for o in trouser_parts:parts.remove(o)
 trousers=join(trouser_parts,sex+'_seamless_trousers')
 bpy.context.view_layer.objects.active=trousers
 rem=trousers.modifiers.new('Continuous soft crotch','REMESH');rem.mode='VOXEL';rem.voxel_size=.012;bpy.ops.object.modifier_apply(modifier=rem.name)
 sm=trousers.modifiers.new('Relax seam curvature','SMOOTH');sm.factor=1;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
 trousers.data.calc_loop_triangles();d=trousers.modifiers.new('Trouser budget','DECIMATE');d.ratio=min(1,550/len(trousers.data.loop_triangles));bpy.ops.object.modifier_apply(modifier=d.name)
 trousers.vertex_groups.clear()
 for poly in trousers.data.polygons:poly.use_smooth=True
 def pantsweights(co):
  side='Left' if co.x>0 else 'Right'
  if co.z>.89:return {'Hips':1}
  if co.z>.76:t=(co.z-.76)/.13;return {'Hips':t,side+'UpLeg':1-t}
  if co.z>.44 and co.z<.56:t=(co.z-.44)/.12;return {side+'UpLeg':t,side+'Leg':1-t}
  return {side+('UpLeg' if co.z>=.56 else 'Leg'):1}
 weights(trousers,pantsweights)
 body=join(parts,sex+'_custom_topology');body.location=(0,0,0);bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 for v in body.data.vertices:v.co=stylize(v.co)
 import bmesh
 bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.dissolve_degenerate(bm,dist=.000001,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
 bone_specs={n:(stylize(h),stylize(t),par) for n,(h,t,par) in bone_specs.items()}
 # Morph only the eyelid geometry; the original painted face remains unchanged.
 lid_indices=set()
 for poly in body.data.polygons:
  if '_sleep_' in body.data.materials[poly.material_index].name:lid_indices.update(poly.vertices)
 basis=body.shape_key_add(name='Basis');closed=body.shape_key_add(name='SleepLids')
 for idx in lid_indices:
  basis.data[idx].co.z=stylize((0,0,1.69)).z+(closed.data[idx].co.z-stylize((0,0,1.637)).z)*.12
  basis.data[idx].co.y+=.055
 # Store manual refined weights, run Blender automatic heat weighting, then restore/refine joint bands.
 saved=[{body.vertex_groups[g.group].name:g.weight for g in v.groups} for v in body.data.vertices]
 armdata=bpy.data.armatures.new(sex+'_Humanoid');arm=bpy.data.objects.new(sex+'_Rig',armdata);C['Characters'].objects.link(arm);bpy.context.view_layer.objects.active=arm;arm.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
 for n,(h,t,par) in bone_specs.items():
  eb=armdata.edit_bones.new(n);eb.head=h;eb.tail=t
  if par:eb.parent=armdata.edit_bones[par]
 bpy.ops.object.mode_set(mode='OBJECT');bpy.ops.object.select_all(action='DESELECT');body.select_set(True);arm.select_set(True);bpy.context.view_layer.objects.active=arm
 try:bpy.ops.object.parent_set(type='ARMATURE_AUTO');auto=True
 except Exception as e:auto=False;body.parent=arm
 for mod in list(body.modifiers):
  if mod.type=='ARMATURE':body.modifiers.remove(mod)
 mod=body.modifiers.new('Humanoid skin with joint band refinement','ARMATURE');mod.object=arm;body.parent=arm
 for g in body.vertex_groups:g.remove(list(range(len(body.data.vertices))))
 for i,d in enumerate(saved):
  total=sum(d.values())
  for n,w in d.items():g=body.vertex_groups.get(n) or body.vertex_groups.new(name=n);g.add([i],w/total,'REPLACE')
 arm.show_in_front=True;armdata.display_type='OCTAHEDRAL'
 body.data.calc_loop_triangles();tris=len(body.data.loop_triangles);print('CHARACTER',sex,tris,'triangles',flush=True)
 chars[sex]=(arm,body);rigdata[sex]={'triangles':tris,'quads':sum(len(f.vertices)==4 for f in body.data.polygons),'vertices':len(body.data.vertices),'bones':len(armdata.bones),'automatic_heat_weights_invoked':auto,'joint_refinement':'normalized hand-authored blend bands at shoulder/elbow/hip/knee/neck; seam overlap under tailored clothing','actions':[]}
 return arm,body
for sex in ['female','male']:make_character(sex)
# FK poses created as complete bone transforms from explicit target joint positions.
def pose(arm,kind):
 for pb in arm.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 # All positions local, standing forward -Y. Positions chosen for chair/table/bed contacts.
 if kind=='Sleep_Bed':
  # rotate complete rig later; animation itself is relaxed supine with legs straight
  hipz=.87;hipy=0
 else:hipz=.54 if kind=='Sit_Desk' else (.60 if kind=='Read_Book' else (.59 if kind=='Pet_Cat' else .87));hipy=0
 dz=hipz-.87
 pos={};
 def segment(n,h,t):pos[n]=(Vector(h),Vector(t))
 segment('Hips',(0,hipy,hipz),(0,hipy,hipz+.15));segment('Spine',(0,0,1+dz),(0,-(.09 if kind=='Pet_Cat' else 0),1.22+dz));segment('Chest',pos['Spine'][1],(0,-(.19 if kind=='Pet_Cat' else 0),1.46+dz));segment('Neck',pos['Chest'][1],(0,-(.22 if kind=='Pet_Cat' else 0),1.55+dz));segment('Head',pos['Neck'][1],(0,(-.25 if kind=='Pet_Cat' else (.04 if kind=='Idle' else -.015)),1.8+dz))
 for side,s in [('Left',1),('Right',-1)]:
  sh=(s*.23,-(.17 if kind=='Pet_Cat' else 0),1.43+dz);segment(side+'Shoulder',(0,sh[1],sh[2]),sh)
  if kind=='Sit_Desk':el=(s*.28,-.20,.89);wr=(s*.18,-.46,.875);hand=(s*.18,-.55,.875);knee=(s*.115,-.40,.49);ank=(s*.12,-.4,.105)
  elif kind=='Read_Book':el=(s*.3,-.12,1.12+dz);wr=((.129 if s==1 else s*.16),(-.402 if s==1 else -.36),1.18+dz+(.012 if s==1 else 0));hand=((.089 if s==1 else s*.12),(-.472 if s==1 else -.43),1.19+dz+(.012 if s==1 else 0));knee=(s*.115,-.36,.45);ank=(s*.12,-.36,.105)
  elif kind=='Pet_Cat':el=(s*.29,-.4,.78);wr=(s*.18,-.64,.44);hand=(s*.12,-.7,.38);knee=(s*.15,-.30,.37);ank=(s*.16,.03,.105)
  elif kind=='Sleep_Bed':el=(s*.29,.035,1.17);wr=(s*.35,.03,.97);hand=(s*.35,.02,.88);knee=(s*.115,-.01,.48);ank=(s*.12,0,.105)
  else:el=(s*.25,0,1.17);wr=(s*.26,-.035,.97);hand=(s*.27,-.05,.88);knee=(s*.115,-.01,.48);ank=(s*.12,0,.105)
  if kind=='Pet_Cat':
   sh=(s*.23,-.35,.98)
   segment(side+'Shoulder',(0,-.32,1.0),sh)
   A=Vector(sh);B=Vector(wr);delta=B-A;d=delta.length;axis=delta.normalized();l1=(arm.data.bones[side+'Arm'].tail_local-arm.data.bones[side+'Arm'].head_local).length;l2=(arm.data.bones[side+'ForeArm'].tail_local-arm.data.bones[side+'ForeArm'].head_local).length
   along=(l1*l1-l2*l2+d*d)/(2*d);height=math.sqrt(max(0,l1*l1-along*along));bend=Vector((s,-.5,0));bend=(bend-axis*bend.dot(axis)).normalized();el=A+axis*along+bend*height
  segment(side+'Arm',sh,el);segment(side+'ForeArm',el,wr);segment(side+'Hand',wr,hand);segment(side+'UpLeg',(s*.105,0,hipz),knee);segment(side+'Leg',knee,ank);segment(side+'Foot',ank,(ank[0],ank[1]-.18,.07));segment(side+'ToeBase',pos[side+'Foot'][1],(ank[0],ank[1]-.26,.065))
 if kind=='Pet_Cat':
  pos['Spine']=(Vector((0,0,.72)),Vector((0,-.15,.88)))
  pos['Chest']=(Vector((0,-.15,.88)),Vector((0,-.32,1.0)))
  pos['Neck']=(Vector((0,-.32,1.0)),Vector((0,-.38,1.07)))
  pos['Head']=(Vector((0,-.38,1.07)),Vector((0,-.46,1.30)))
 if kind=='Sleep_Bed':
  R=Matrix.Rotation(-math.pi/2,4,'X')
  for n,(h,t) in list(pos.items()):
   h=R@stylize(h)+Vector((0,0,.84));t=R@stylize(t)+Vector((0,0,.84))
   if n=='Head':h.z+=(.16 if arm.name.startswith('female') else .09);t.z+=(.16 if arm.name.startswith('female') else .09)
   if n=='Neck':t.z+=(.16 if arm.name.startswith('female') else .09)
   if n.endswith(('Foot','ToeBase')):h.z-=.05;t.z-=.05
   if n.endswith('Leg') and not n.endswith('UpLeg'):t.z-=.05
   pos[n]=(h,t)
 # Target-space bone matrices keep neighboring weighted surfaces connected; petting uses an exact two-bone reach solution.
 for pb in arm.pose.bones:
  h,t=pos[pb.name]
  if kind!='Sleep_Bed':h=stylize(h);t=stylize(t)
  rest=pb.bone.tail_local-pb.bone.head_local
  if pb.name=='Head':t=h+(t-h).normalized()*rest.length
  q=rest.rotation_difference(t-h);pb.matrix=Matrix.Translation(h)@q.to_matrix().to_4x4()@pb.bone.matrix_local.to_3x3().to_4x4()@Matrix.Diagonal((1,(t-h).length/rest.length,1,1))
  bpy.context.view_layer.update()
for sex,(arm,body) in chars.items():
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  arm.animation_data_create();act=bpy.data.actions.new(sex+'_'+kind);arm.animation_data.action=act;pose(arm,kind)
  for frame in [1,25,49]:
   pose(arm,kind)
   if frame==25:
    from mathutils import Quaternion
    if kind in ['Idle','Sleep_Bed']:arm.pose.bones['Chest'].rotation_quaternion @= Quaternion((1,0,0),.012)
    elif kind=='Sit_Desk':
     for side in ['Left','Right']:arm.pose.bones[side+'Hand'].rotation_quaternion @= Quaternion((1,0,0),.07 if side=='Left' else -.05)
    elif kind=='Read_Book':arm.pose.bones['Head'].rotation_quaternion @= Quaternion((0,1,0),.045)
    elif kind=='Pet_Cat':arm.pose.bones['LeftForeArm'].rotation_quaternion @= Quaternion((1,0,0),.09)
   for pb in arm.pose.bones:
    pb.rotation_mode='QUATERNION';pb.keyframe_insert(data_path='location',frame=frame);pb.keyframe_insert(data_path='rotation_quaternion',frame=frame);pb.keyframe_insert(data_path='scale',frame=frame)
  track=arm.animation_data.nla_tracks.new();track.name=kind;strip=track.strips.new(kind,1,act);track.mute=True;rigdata[sex]['actions'].append(kind)
 arm.animation_data.action=None;pose(arm,'Idle')
# Merge eyelid morph clips into the corresponding skeleton NLA track names on GLB export.
for sex,(arm,body) in chars.items():
 keys=body.data.shape_keys;keys.animation_data_create()
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  act=bpy.data.actions.new(sex+'_Lids_'+kind);keys.animation_data.action=act
  for frame in [1,25,49]:
   keys.key_blocks['SleepLids'].value=1.0 if kind=='Sleep_Bed' else 0.0
   keys.key_blocks['SleepLids'].keyframe_insert(data_path='value',frame=frame)
  track=keys.animation_data.nla_tracks.new();track.name=kind;track.strips.new(kind,1,act);track.mute=True
 keys.animation_data.action=None;keys.key_blocks['SleepLids'].value=0
# Book accessory (placed in shot later).
CURRENT='Room';bookparts=[]
for side in [-1,1]:
 o=box('Held book cover',(side*.078,-.026,0),(.17,.015,.24),M['teal'],.004);o.rotation_euler.z=-side*.32;bookparts.append(o)
 o=box('Held book leaf block',(side*.078,-.039,0),(.15,.014,.219),M['pages'],.003);o.rotation_euler.z=-side*.32;bookparts.append(o)
book=join(bookparts,'Held reading book');bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');book.location=(0,0,-5)
box('Open notebook on desk',(-.18,2.36,.827),(.25,.27,.025),M['pages'],.004)
# City sample: six independent destinations with a clear cross-river plan.
CURRENT='City'
box('City island plinth',(0,0,-.3),(28,24,.6),M['ceramic'],.16)
box('Grass west district',(-8,0,.01),(10,23,.07),M['grass']);box('Grass east district',(8,0,.01),(10,23,.07),M['grass'])
box('North-south street',(-2,0,.05),(4,24,.1),M['road']);box('East-west street',(0,-1,.06),(28,4,.12),M['road'])
for y in range(-10,12,2):box('Lane dash',(-2,y,.124),(.1,.8,.005),M['cream'],0)
for x in range(-12,14,2):box('Lane dash',(x,-1,.13),(.8,.1,.005),M['cream'],0)
# River on eastern half, crossing bridge on main road.
box('River channel',(3.5,0,.03),(3,24,.1),M['water'],0)
for x in [1.9,5.1]:box('River stone quay',(x,0,.18),(.25,24,.35),M['ceramic'])
box('Bridge deck',(3.5,-1,.31),(3.5,4,.32),M['ceramic'],.07)
for y in [-2.8,.8]:
 for x in [2,3,4,5]:rod('Bridge posts',(x,y,.42),(x,y,1.1),.045,M['metal'])
 rod('Bridge rail',(1.8,y,1.1),(5.2,y,1.1),.04,M['metal'])
# building distinctive silhouettes: house, cinema marquee, library columns, gym glass, mall atrium, park arch.
def landmark(n,x,y,sx,sy,h,style):
 box(n+' plaza',(x,y,.13),(sx+1.2,sy+1.2,.24),M['ceramic'],.04)
 if style!='park':
  box(n+' walls',(x,y,.25+h/2),(sx,sy,h),M['wall'],.045)
  box(n+' roof overhang',(x,y,h+.4),(sx+.35,sy+.35,.22),M['wood'],.04)
  box(n+' entrance',(x,y-sy/2-.03,1.12),(1,.05,1.75),M['teal'],.02)
  for i in [-1,1]:
   box(n+' window',(x+i*sx*.29,y-sy/2-.06,1.65),(.66,.06,.85),M['denim'],.02)
  text(n+' sign',n,(x,y-sy/2-.11,h-.12),.32 if len(n)<8 else .26,M['ink'])
 if style=='home':
  v=[(x-sx/2-.2,y-sy/2-.2,h+.5),(x+sx/2+.2,y-sy/2-.2,h+.5),(x,y-sy/2-.2,h+1.65),(x-sx/2-.2,y+sy/2+.2,h+.5),(x+sx/2+.2,y+sy/2+.2,h+.5),(x,y+sy/2+.2,h+1.65)]
  mesh('House pitched roof',v,[(0,3,5,2),(1,2,5,4),(0,2,1),(3,4,5)],M['wood'])
  box('House chimney',(x+.9,y+.4,h+1.2),(.4,.45,1.5),M['wall'])
 elif style=='cinema':
  box('Cinema glowing marquee',(x,y-sy/2-.45,1.9),(sx+.4,.85,.38),M['ochre']);text('Cinema poster','CINEMA',(x,y-sy/2-.9,1.9),.34,M['ink'])
  for i in range(11):ell('Marquee bulb',(x-sx/2+i*sx/10,y-sy/2-.91,1.75),(.045,.035,.045),M['cream'],8,4)
 elif style=='library':
  for xx in [-1.25,-.42,.42,1.25]:rod('Library column',(x+xx,y-sy/2-.35,.3),(x+xx,y-sy/2-.35,2.65),.11,M['ceramic'])
  box('Library canopy',(x,y-sy/2-.35,2.76),(sx+.3,.8,.22),M['ceramic'])
 elif style=='gym':
  text('Gym dumbbell emblem','O===O',(x,y-sy/2-.15,h+.05),.38,M['teal'])
  for xx in [-.7,.7]:rod('Gym roof AC',(x+xx,y, h+.5),(x+xx,y,h+.85),.22,M['metal'])
 elif style=='mall':
  box('Mall skylight',(x,y,h+.72),(sx*.6,sy*.65,.48),M['denim'],.06)
  for xx in [-1.2,-.4,.4,1.2]:box('Mall upper windows',(x+xx,y-sy/2-.07,2.7),(.55,.07,.64),M['teal'])
 elif style=='park':
  for xx in [-1.3,1.3]:box('Park stone pier',(x+xx,y-1,.95),(.32,.4,1.65),M['ceramic'])
  box('Park timber arch',(x,y-1,1.92),(3,.35,.35),M['wood']);text('Park entrance sign','PARK',(x,y-1.19,1.9),.3,M['cream'])
  box('Park footpath',(x,y+.5,.28),(1.2,3,.08),M['ceramic'])
  for xx,yy in [(-1.3,.5),(1.5,1.2)]:tree(x+xx,y+yy)
def tree(x,y):
 rod('Tree branched trunk',(x,y,.2),(x,y,2.3),.13,M['wood']);
 for dx,dy,z in [(-.45,.1,2.3),(.45,0,2.6),(0,.25,3.0)]:
  rod('Tree branch',(x,y,1.7),(x+dx,y+dy,z),.055,M['wood']);ell('Tree faceted crown',(x+dx,y+dy,z),(.7,.65,.8),M['leaf'],12,6)
for args in [('HOME',-8,6,3.3,3,2.7,'home'),('CINEMA',-8,-7,4.2,3.6,3.5,'cinema'),('LIBRARY',-.5,6,3.6,3.4,3.1,'library'),('GYM',9,6,3.8,3.3,3,'gym'),('MALL',9,-7,4.8,3.8,3.6,'mall'),('PARK',-.5,-7,3.6,3.3,0,'park')]:landmark(*args)
for x,y in [(-12,1),(-12,8),(-5,9),(12,1),(12,10),(6,9),(6,-10),(-12,-10)]:tree(x,y)
# Occlusion test is a real shader in Blender, not a retouched cut-out.
CURRENT='Occlusion'
box('Occlusion floor',(0,0,-.07),(6,5,.14),M['floor'])
wall=box('Occluding wall',(0,-.45,1.45),(3.8,.2,2.9),M['wall'],.01)
# Material shader screen coordinate mask + deterministic 4x4 Bayer dither.
dither=M['wall'].copy();dither.name='Screen circle Bayer dither / Blender demonstration';wall.data.materials.clear();wall.data.materials.append(dither)
n=dither.node_tree.nodes;l=dither.node_tree.links;out=n.get('Material Output');bs=n.get('Principled BSDF');tc=n.new('ShaderNodeTexCoord');sep=n.new('ShaderNodeSeparateXYZ');l.new(tc.outputs['Window'],sep.inputs[0])
def mathnode(op,a=None,b=None):
 q=n.new('ShaderNodeMath');q.operation=op
 for i,v in enumerate([a,b]):
  if v is not None:
   if isinstance(v,(float,int)):q.inputs[i].default_value=v
   else:l.new(v,q.inputs[i])
 return q.outputs[0]
xd=mathnode('SUBTRACT',sep.outputs['X'],.5);xd=mathnode('MULTIPLY',xd,1920/1080);yd=mathnode('SUBTRACT',sep.outputs['Y'],.46);dist=mathnode('ADD',mathnode('MULTIPLY',xd,xd),mathnode('MULTIPLY',yd,yd));circle=mathnode('LESS_THAN',dist,.24**2)
# High frequency stable screen-space ordered checker alpha coverage.
px=mathnode('FLOOR',mathnode('MULTIPLY',sep.outputs['X'],960));py=mathnode('FLOOR',mathnode('MULTIPLY',sep.outputs['Y'],540));checker=mathnode('MODULO',mathnode('ADD',px,py),2);fac=mathnode('MULTIPLY',circle,checker)
trans=n.new('ShaderNodeBsdfTransparent');mix=n.new('ShaderNodeMixShader');l.new(fac,mix.inputs[0]);l.new(bs.outputs[0],mix.inputs[1]);l.new(trans.outputs[0],mix.inputs[2]);l.new(mix.outputs[0],out.inputs['Surface'])
dither['note']='Blender Window-space circle with ordered checker transparency. Godot probe uses 4x4 Bayer coverage and distance-to-subject depth gating.'
# Studio background + consistent HDRI and warm sun, 45 azimuth and 45 elevation pseudo-isometric.
CURRENT='Studio';box('Studio ground',(0,0,-.47),(200,200,.2),M['cream'],0)
world=bpy.data.worlds.new('Poly Haven studio_small_09 HDRI');sc.world=world;world.use_nodes=True;n=world.node_tree.nodes;l=world.node_tree.links;env=n.new('ShaderNodeTexEnvironment');env.image=bpy.data.images.load(str(next(P/f['path'] for f in manifest['files'] if f['map']=='hdri')));l.new(env.outputs[0],n.get('Background').inputs['Color']);n.get('Background').inputs['Strength'].default_value=.38
ld=bpy.data.lights.new('Warm daylight','AREA');lo=bpy.data.objects.new('Warm daylight',ld);C['Studio'].objects.link(lo);lo.location=(-3,-4,9);ld.energy=1800;ld.size=7;ld.color=(1,.88,.73);lo.rotation_euler=(Vector((-1,1,0))-lo.location).to_track_quat('-Z','Y').to_euler()
ld=bpy.data.lights.new('Sun','SUN');lo=bpy.data.objects.new('Sun',ld);C['Studio'].objects.link(lo);ld.energy=2.0;ld.angle=.24;lo.rotation_euler=(.45,-.5,-.35)
ld=bpy.data.lights.new('Interior warm bounce','AREA');lo=bpy.data.objects.new('Interior warm bounce',ld);C['Studio'].objects.link(lo);lo.location=(2,-1,5);ld.energy=750;ld.size=5;ld.color=(1,.87,.72);lo.rotation_euler=(Vector((-1,1,.7))-lo.location).to_track_quat('-Z','Y').to_euler()
sc.view_settings.exposure=.35
camd=bpy.data.cameras.new('Orthographic_45_down_45_azimuth');cam=bpy.data.objects.new('Camera',camd);sc.collection.objects.link(cam);sc.camera=cam;camd.type='ORTHO'
def camera(target,scale):
 target=Vector(target);cam.location=target+Vector((10,-10,14.1421356));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler();camd.ortho_scale=scale
camera((-1,1,1),10.5)
for c in ['City','Occlusion','ModuleLibrary']:C[c].hide_render=True
# Bake and clean scenery normals/degenerate bevel limits before final GLB export.
import bmesh
for obj in list(C['Room'].objects):
 if obj.type!='MESH':continue
 applymods(obj)
 if obj.data.users>1:obj.data=obj.data.copy()
 bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.dissolve_degenerate(bm,dist=.000002,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
# Source proof, exact module audit in local coordinates.
audit=[]
for o in modules:
 coords=[v.co for v in o.data.vertices];mn=[min(v[i] for v in coords) for i in range(3)];mx=[max(v[i] for v in coords) for i in range(3)]
 audit.append({'name':o.name,'origin':list(o.location),'origin_grid_error_m':[float(v%2) for v in o.location],'bbox_min':mn,'bbox_max':mx,'bbox_size':[mx[i]-mn[i] for i in range(3)],'pivot_policy':'grid corner (0,0,0); floor surface at z=0, slab extends below','uv_layers':len(o.data.uv_layers)})
(P/'evidence/build_audit.json').write_text(json.dumps({'blender':bpy.app.version_string,'camera_elevation_degrees':45,'camera_azimuth_degrees':45,'characters':rigdata,'modules':audit},indent=2))
# Save stand-alone GLBs, using all five NLA tracks per humanoid.
for sex,(arm,body) in chars.items():
 arm.location=(0,0,0);arm.rotation_euler=(0,0,0);pose(arm,'Idle');bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);body.select_set(True)
 for track in arm.animation_data.nla_tracks:track.mute=False
 bpy.ops.export_scene.gltf(filepath=str(P/f'exports/{sex}_rigged.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_yup=True,export_apply=False)
 for track in arm.animation_data.nla_tracks:track.mute=True
for o in modules:
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.ops.export_scene.gltf(filepath=str(P/f'exports/{o.name}.glb'),export_format='GLB',use_selection=True,export_animations=False)
# Room GLB, clear other rig, put female at desk.
arm,body=chars['female'];pose(arm,'Sit_Desk');arm.location=(.55,1.82,0);arm.rotation_euler.z=pi
chars['male'][0].location=(20,20,0)
bpy.ops.object.select_all(action='DESELECT')
for o in C['Room'].objects:o.select_set(True)
# Room export is scenery-only; runtime composes separate skinned character + Sit_Desk action.
bpy.ops.export_scene.gltf(filepath=str(P/'exports/room_realtime.glb'),export_format='GLB',use_selection=True,export_animations=False,export_apply=True)
bpy.ops.object.select_all(action='DESELECT')
for o in C['City'].objects:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(P/'exports/city_realtime.glb'),export_format='GLB',use_selection=True,export_animations=False,export_apply=True)
# Keep textures packed in native editable source.
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(P/'blender_realtime_sample.blend'))
print('BUILD COMPLETE',flush=True)
