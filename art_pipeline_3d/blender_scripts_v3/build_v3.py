import bpy,math,json,sys,os
from pathlib import Path
from math import sin,cos,pi
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parents[1];V2=P
sys.path.insert(0,str(P/'blender_scripts_v3'))
from pose_utils import stylize,pose
bpy.ops.wm.open_mainfile(filepath=str(V2/'blender_realtime_sample.blend'))
C={n:bpy.data.collections[n] for n in ['Room','Characters','City','Occlusion','Studio','ModuleLibrary']};CURRENT='Characters'
exec((P/'blender_scripts_v3/geometry_helpers.py').read_text())
# All source geometry is authored in the V2 skeleton's design space, then mapped ONCE.
# No flesh exists inside the torso, upper sleeves, or trousers.
def material(name,col,rough,metal=0,texture=None,sheen=0):
 m=bpy.data.materials.new('V3_'+name);m.use_nodes=True;m.diffuse_color=(*col,1)
 b=m.node_tree.nodes.get('Principled BSDF');b.inputs['Base Color'].default_value=(*col,1);b.inputs['Roughness'].default_value=rough;b.inputs['Metallic'].default_value=metal;b.inputs['Sheen Weight'].default_value=sheen
 if texture:
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(P/f'textures/{name}_albedo.png'),check_existing=True);m.node_tree.links.new(t.outputs['Color'],b.inputs['Base Color'])
 if name.startswith('Hair'):b.inputs['Specular IOR Level'].default_value=.24
 if name.startswith('Skin'):b.inputs['Specular IOR Level'].default_value=.30
 if name.startswith('Skin'):b.inputs['Subsurface Weight'].default_value=.065;b.inputs['Subsurface Radius'].default_value=(1,.42,.22)
 if texture:
  n=m.node_tree.nodes;l=m.node_tree.links
  for typ,sock in [('normal','Normal'),('roughness','Roughness')]:
   t=n.new('ShaderNodeTexImage');t.image=bpy.data.images.load(str(P/f'textures/{texture}_{typ}.png'),check_existing=True);t.image.colorspace_settings.name='Non-Color'
   if typ=='normal':
    norm=n.new('ShaderNodeNormalMap');norm.inputs['Strength'].default_value=.24 if texture!='hair' else .10;l.new(t.outputs['Color'],norm.inputs['Color']);l.new(norm.outputs['Normal'],b.inputs['Normal'])
   else:l.new(t.outputs['Color'],b.inputs[sock])
 return m
M={}
M['skinF']=material('Skin_F',(.69,.405,.278),.46,texture='skin')
M['skinM']=material('Skin_M',(.48,.26,.16),.46,texture='skin')
M['hairF']=material('Hair_chestnut',(.055,.019,.012),.45,texture='hair')
M['hairM']=material('Hair_espresso',(.018,.014,.012),.45,texture='hair')
M['shirtF']=material('Knit_sage',(.105,.27,.225),.92,texture='knit',sheen=.10)
M['shirtM']=material('Cotton_midnightblue',(.045,.12,.23),.90,texture='cotton',sheen=.08)
M['pantsF']=material('Denim_indigo',(.035,.065,.115),.88,texture='denim',sheen=.08)
M['pantsM']=material('Chinos_slate',(.17,.20,.19),.89,texture='denim',sheen=.08)
M['rubber']=material('Rubber_cupsole',(.69,.68,.59),.39,texture='rubber')
M['shoe']=material('Canvas_shoe',(.20,.22,.205),.54,texture='canvas')
M['trim']=material('Collar_binding',(.46,.49,.39),.86,texture='knit')
M['dark']=material('Recess_shadow',(.012,.016,.013),.95)
M['metal']=material('Brushed_fasteners',(.65,.55,.35),.19,1)
M['white']=material('Eye_sclera',(.82,.78,.67),.30)
M['iris']=material('Iris_hazel',(.09,.065,.021),.25)
M['pupil']=material('Pupil',(.006,.004,.003),.22)
M['lip']=material('Lip_warm',(.32,.093,.065),.48)
M['lace']=material('Cotton_laces',(.73,.70,.61),.87)

def make(sex):
 fem=sex=='female';arm=bpy.data.objects[sex+'_Rig'];old=bpy.data.objects[sex+'_custom_topology'];bpy.data.objects.remove(old,do_unlink=True)
 for bone in arm.data.bones:bone.inherit_scale='FULL'
 arm.location=(0,0,0);arm.rotation_euler=(0,0,0);arm.animation_data.action=None
 for tr in arm.animation_data.nla_tracks:tr.mute=True
 for pb in arm.pose.bones:pb.matrix_basis=Matrix.Identity(4)
 parts=[];skin=M['skinF' if fem else 'skinM'];hair=M['hairF' if fem else 'hairM'];shirt=M['shirtF' if fem else 'shirtM'];pants=M['pantsF' if fem else 'pantsM']
 def rigid(n):return lambda co:{n:1}
 def add(o,fn):
  for v in o.data.vertices:
   for n,w in fn(v.co).items():
    if w>1e-8:
     g=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);g.add([v.index],w,'REPLACE')
  parts.append(o);return o
 def torso_w(co):
  if co.z<1.04:return {'Hips':1}
  t=max(0,min(1,(co.z-1.04)/.20));return {'Spine':1-t,'Chest':t}
 def loft(name,rs,mat,fn,N=32,exponent=1,caps=False):
  vv=[];ff=[];uv=[]
  for j,(z,rx,ry,cy) in enumerate(rs):
   for i in range(N):
    a=2*pi*i/N;ss=sin(a);cc=cos(a);vv.append((math.copysign(abs(ss)**exponent,ss)*rx,-math.copysign(abs(cc)**exponent,cc)*ry+cy,z));uv.append(((i/N+(.5 if 'Sculpted jaw' in name else .75))%1,j/max(1,len(rs)-1)))
  for j in range(len(rs)-1):
   for i in range(N):a=j*N+i;b=j*N+(i+1)%N;ff.append((a,b,b+N,a+N))
  if caps:ff += [tuple(reversed(range(N))),tuple((len(rs)-1)*N+i for i in range(N))]
  return add(mesh(name,vv,ff,mat,uv),fn)
 def sweep(name,points,radii,mat,ws,N=12,cap=True):
  vs=[];fs=[];uv=[]
  for j,p in enumerate(points):
   p=Vector(p);t=(Vector(points[min(j+1,len(points)-1)])-Vector(points[max(0,j-1)])).normalized();u=t.cross(Vector((0,1,0))).normalized();v=t.cross(u).normalized()
   for i in range(N):
    a=2*pi*i/N;asym=(.83 if name.startswith('Loose sleeve') and j==5 and sin(a)>0 else 1.0)
    vs.append(p+u*cos(a)*radii[j][0]+v*sin(a)*radii[j][1]*asym);uv.append(((i/N+(.5 if points[0][0]>0 else 0))%1,j/max(1,len(points)-1)))
  for j in range(len(points)-1):
   for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
  if cap:fs.extend([tuple(reversed(range(N))),tuple((len(points)-1)*N+i for i in range(N))])
  o=mesh(name,vs,fs,mat,uv)
  for j in range(len(points)):
   for n,w in ws[j].items():
    if w>0:
     g=o.vertex_groups.get(n) or o.vertex_groups.new(name=n);g.add(list(range(j*N,(j+1)*N)),w,'REPLACE')
  parts.append(o);return o
 # Open hollow sweater: outer 12mm lip, vertical folded return, then recessed INNER seam.
 hem=.994
 loft('Hanging shirt shell',[(hem,.185,.119,0),(1.014,.185,.119,0),(1.055,.178,.115,-.002),(1.13,.167,.108,0),(1.23,.190 if fem else .204,.116,-.006),(1.34,.222 if fem else .235,.106,0),(1.385,.232 if fem else .245,.094,0),(1.419,.195,.084,0),(1.450,.077,.067,0)],shirt,torso_w,32,.72)
 loft('Hem extruded folded lip',[(1.017,.1855,.1195,0),(.994,.190,.124,0),(.982,.190,.124,0),(.982,.175,.109,0),(1.008,.175,.109,0)],shirt,torso_w,32,.72)
 loft('Hem recessed shadow channel',[(1.008,.172,.106,0),(.989,.172,.106,0)],M['dark'],torso_w,32,.72)
 # Neckline is physically inset, not a color painted onto a solid torso.
 loft('Neck rib lip',[(1.439,.083,.072,0),(1.458,.083,.072,0),(1.463,.065,.055,0),(1.438,.063,.053,0)],shirt,rigid('Chest'),32,.85)
 loft('Neck dark cavity',[(1.438,.062,.052,0),(1.421,.061,.051,0)],M['dark'],rigid('Chest'),24)
 loft('Only exposed neck',[(1.43,.045,.041,0),(1.48,.047,.042,0),(1.52,.060,.050,0),(1.55,.071,.056,0)],skin,lambda co:{'Neck':min(1,max(0,(1.55-co.z)/.10)),'Head':min(1,max(0,(co.z-1.45)/.10))},24)
 # Sculpted face: chin plane, jaw angle, cheek prominence, brow, integrated bridge/tip.
 rs=[(1.495,.036,.041,-.018),(1.510,.064,.059,-.013),(1.530,.088,.070,-.006),(1.552,.103 if not fem else .097,.080,0),(1.578,.102,.089,0),(1.602,.110,.095,0),(1.625,.113,.096,0),(1.648,.113,.095,0),(1.670,.112,.100,0),(1.695,.114,.102,0),(1.72,.109,.100,0),(1.744,.096,.088,0),(1.766,.075,.067,0),(1.783,.040,.038,0),(1.791,.009,.009,0)]
 head=loft('Sculpted jaw cheek brow',rs,skin,rigid('Head'),40,1,True)
 for v in head.data.vertices:
  x,y,z=v.co
  if y<0:
   f=max(0,1-(abs(x)/.115)**2)
   v.co.y-=.039*math.exp(-(x/.023)**2-((z-1.624)/.025)**2)*f
   v.co.y-=.012*math.exp(-(x/.018)**2-((z-1.654)/.042)**2)*f
   v.co.y-=.005*math.exp(-((abs(x)-.065)/.029)**2-((z-1.609)/.027)**2)
 for s in [-1,1]:
  add(ell('Ear helix',(s*.113,.002,1.618),(.018,.018,.031),skin,12,8),rigid('Head'))
  add(ell('Ear inner',(s*.126,-.010,1.618),(.006,.006,.017),M['lip'],8,6),rigid('Head'))
  # Eye geometry actual recessed spheroids. Shape key closes all eye geometry coherently.
  xx=s*.050;yy=-.092;zz=1.646
  for name,loc,sz,mat in [('EyeWhite',(xx,yy-.002,zz),(.026,.009,.014),M['white']),('EyeIris',(xx,yy-.010,zz),(.011,.003,.011),M['iris']),('EyePupil',(xx,yy-.013,zz),(.005,.002,.007),M['pupil']),('EyeGlint',(xx-.003,yy-.015,zz+.004),(.0025,.001,.0025),M['white'])]:
   o=add(ell(name,loc,sz,mat,16,8),rigid('Head'));o['eye_morph']=True
  pts=[(xx-.028,-.096,zz+.002),(xx-.018,-.100,zz+.014),(xx,-.102,zz+.017),(xx+.019,-.100,zz+.011),(xx+.028,-.096,zz+.001)]
  sweep('Upper eyelid rim',pts,[(.0025,.0025)]*5,skin,[{'Head':1}]*5,6)
  pts=[(xx-.024,-.096,1.677),(xx-.008,-.102,1.681),(xx+.016,-.099,1.679),(xx+.027,-.095,1.675)]
  sweep('Expressive brows',pts,[(.0035,.0025),(.004,.003),(.003,.002),(.001,.001)],hair,[{'Head':1}]*4,6)
 pts=[(-.029,-.090,1.571),(-.014,-.096,1.568),(0,-.098,1.569),(.014,-.096,1.568),(.029,-.090,1.572)]
 sweep('Subtle smile',pts,[(.0015,.0015)]*5,M['lip'],[{'Head':1}]*5,6)
 # Sculpted hair shell with directional wave; front hairline differs by sex.
 vv=[];ff=[];uv=[];N=40;B=12
 for j in range(B):
  for i in range(N):
   a=2*pi*i/N;front=max(0,cos(a));base=(1.670 if fem else 1.655)+front*(.047 if fem else .052)
   z=base+(1.809-base)*j/(B-1);q=(z-1.686)/.132;r=math.sqrt(max(.009,1-q*q));wave=1+.003*cos(a*14+j*.4)
   vv.append((sin(a)*.124*r*wave,-cos(a)*.114*r*wave+.009,z));uv.append(((i/N+.5)%1,j/(B-1)))
 for j in range(B-1):
  for i in range(N):a=j*N+i;b=j*N+(i+1)%N;ff.append((a,b,b+N,a+N))
 ff.append(tuple((B-1)*N+i for i in range(N)));add(mesh('Parted hair sculpt shell',vv,ff,hair,uv),rigid('Head'))
 # Tapered multi-section lens locks; curves follow skull instead of clay-ball patches.
 def lock(name,pts,widths,depths):return sweep(name,pts,list(zip(widths,depths)),hair,[{'Head':1}]*len(pts),10)
 if fem:
  for s in [-1,1]:
   for k in range(2):
    shift=k*.019
    lock('Curtain fringe sculpt',[(s*(.009+shift),-.079,1.794-k*.006),(s*(.037+shift),-.107,1.771-k*.007),(s*(.071+shift*.7),-.112,1.731-k*.008),(s*(.102+shift*.3),-.101,1.682-k*.008),(s*.116,-.081,1.641-k*.008)],[.009,.026,.026,.016,.0015],[.006,.009,.009,.007,.0015])
   lock('Long face framing strand',[(s*.108,-.018,1.739),(s*.124,-.030,1.674),(s*.126,-.041,1.598),(s*.113,-.057,1.526)],[.022,.021,.018,.002],[.019,.021,.017,.002])
  lock('Low tied tail',[(0,.100,1.683),(.016,.146,1.651),(.025,.174,1.587),(.023,.180,1.514),(.006,.160,1.455)],[.039,.050,.047,.036,.005],[.031,.038,.031,.024,.004])
  add(ell('Hair tie',(0,.121,1.673),(.040,.014,.017),M['metal'],12,6),rigid('Head'))
 else:
  for k in range(7):
   x=-.095+k*.031
   lock('Short swept fringe',[(x+.025,-.042,1.791),(x+.016,-.084,1.773),(x,-.114,1.734),(x-.012,-.115,1.690+(k%3)*.007)],[.012,.019,.017,.001],[.003,.005,.005,.001])
  for s in [-1,1]:lock('Crisp sideburn',[(s*.111,-.013,1.708),(s*.122,-.021,1.668),(s*.119,-.029,1.636)],[.016,.015,.002],[.015,.013,.002])
 # Sleeves with ease; angular fold rows near elbows; exposed forearm beneath folded cuff.
 for side,s in [('Left',1),('Right',-1)]:
  A=side+'Arm';B=side+'ForeArm';H=side+'Hand';L=side+'UpLeg';K=side+'Leg';F=side+'Foot'
  pts=[(s*.142,0,1.366),(s*.222,0,1.342),(s*.253,0,1.275),(s*.255,-.001,1.224),(s*.258,-.007,1.207),(s*.252,-.001,1.187),(s*.259,-.012,1.167),(s*.260,-.022,1.101)]
  rr=[(.052,.061),(.064,.065),(.062,.062),(.058,.057),(.059,.058),(.053,.052),(.055,.054),(.047,.046)]
  ws=[{'Chest':.3,A:.7},{A:1},{A:1},{A:.8,B:.2},{A:.7,B:.3},{A:.5,B:.5},{A:.3,B:.7},{B:1}]
  sweep('Loose sleeve elbow pleats',pts,rr,shirt,ws,16,False)
  # Inset return builds real 10mm folded sleeve thickness.
  pts2=[(s*.260,-.022,1.114),(s*.260,-.022,1.087),(s*.260,-.022,1.087),(s*.260,-.022,1.112)]
  sweep('Folded sleeve cuff',pts2,[(.050,.049),(.050,.049),(.036,.035),(.036,.035)],shirt,[{B:1}]*4,16,False)
  sweep('Cuff inner shadow',[(s*.260,-.022,1.110),(s*.260,-.022,1.092)],[(.035,.034)]*2,M['dark'],[{B:1}]*2,12,False)
  sweep('Exposed lower forearm',[(s*.260,-.022,1.105),(s*.260,-.030,1.025),(s*.260,-.035,.974)],[(.029,.027),(.026,.024),(.022,.020)],skin,[{B:1},{B:1},{B:.7,H:.3}],12)
  # Palm is a flattened plane with knuckles; four readable independent fingertip blocks.
  o=box('Flattened palm',(s*.263,-.037,.946),(.053,.035,.060),skin,.009);add(o,rigid(H))
  for k in range(4):
   x=s*(.243+k*.013);length=[.040,.050,.046,.035][k]
   sweep('Finger block',[(x,-.040,.926),(x,-.043,.910),(x,-.048,.926-length)],[(.0065,.008),(.0065,.0075),(.005,.005)],skin,[{H:1}]*3,8)
  sweep('Opposed thumb',[(s*.239,-.044,.959),(s*.228,-.056,.941),(s*.229,-.066,.927)],[(.010,.010),(.009,.009),(.006,.006)],skin,[{H:1}]*3,8)
  # Shoes: flat outsole, raised welt, shaped toe box, heel counter and metal eyelets.
  xx=s*.12
  def shoe_shell(name,levels,mat):
   vs=[];fs=[];uv=[];N=24
   for j,(z,w,length,cy) in enumerate(levels):
    for i in range(N):
     a=2*pi*i/N;vs.append((xx+w*math.copysign(abs(sin(a))**.72,sin(a)),cy-length*math.copysign(abs(cos(a))**.8,cos(a)),z));uv.append(((i/N+.5)%1,j/max(1,len(levels)-1)))
   for j in range(len(levels)-1):
    for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
   fs += [tuple(reversed(range(N))),tuple((len(levels)-1)*N+i for i in range(N))]
   return add(mesh(name,vs,fs,mat,uv),rigid(F))
  shoe_shell('Flat thick rubber cupsole',[(.003,.065,.138,-.055),(.018,.072,.144,-.055),(.046,.072,.144,-.055),(.053,.065,.138,-.055)],M['rubber'])
  shoe_shell('Canvas shaped toe box',[(.050,.063,.130,-.052),(.077,.063,.128,-.049),(.099,.060,.106,-.030),(.143,.046,.052,.008),(.146,.038,.044,.008),(.124,.036,.040,.008)],M['shoe'])
  add(mesh('Raised sneaker tongue',[(xx-.031,-.111,.119),(xx+.031,-.111,.119),(xx+.030,-.006,.158),(xx-.030,-.006,.158)],[(0,1,2,3)],M['shoe']),rigid(F))
  for yy,z in [(-.086,.130),(-.054,.142),(-.025,.154)]:
   add(rod('Crossed cotton lace',(xx-.025,yy,z),(xx+.025,yy+.008,z),.003,M['lace'],8),rigid(F))
   for ss in [-1,1]:add(ell('Metal lace eyelet',(xx+ss*.029,yy,z-.002),(.006,.006,.0025),M['metal'],8,4),rigid(F))
 # Continuous bifurcated trouser topology: no overlapping cylindrical pelvis caps.
 vs=[];fs=[];uv=[];N=24
 for j,(z,rx,ry) in enumerate([(.815,.174,.096),(.86,.177,.099),(.93,.166,.096),(1.005,.162,.094)]):
  for i in range(N):a=2*pi*i/N;vs.append((rx*sin(a),-ry*cos(a),z));uv.append(((i/N+.75)%1,j*.10))
 for j in range(3):
  for i in range(N):a=j*N+i;b=j*N+(i+1)%N;fs.append((a,b,b+N,a+N))
 # Five common interior crotch bridge points, shared by BOTH legs, not duplicate surfaces.
 bridge=[]
 for k in range(1,6):bridge.append(len(vs));vs.append((0,.096-k*.032,.792));uv.append((.5,k*.02))
 for s,side in [(1,'Left'),(-1,'Right')]:
  loop=(list(range(13))+bridge) if s==1 else ([0]+list(range(23,11,-1))+bridge)
  # right branch bridge must run back -> front too, matching outer arc order.
  prev=loop
  for j,(z,cx,rx,ry,cy) in enumerate([(.758,.097,.083,.087,0),(.64,.108,.073,.075,0),(.55,.113,.066,.070,-.004),(.505,.115,.068,.071,-.006),(.482,.115,.061,.061,-.010),(.462,.115,.069,.070,-.009),(.432,.116,.062,.061,-.007),(.31,.119,.057,.055,0),(.162,.120,.050,.048,0),(.146,.120,.054,.052,0),(.136,.120,.054,.052,0),(.136,.120,.041,.039,0),(.164,.120,.041,.039,0)]):
   curr=[]
   angles=[k*pi/12 for k in range(13)]+[pi+k*pi/6 for k in range(1,6)]
   for i,a in enumerate(angles):
    curr.append(len(vs));vs.append((s*(cx+rx*sin(a)),-ry*cos(a)*( .83 if j==4 and cos(a)<0 else 1.0)+cy,z));uv.append(((a/(2*pi)+.25)%1,.4+j*.045))
   for i in range(18):fs.append((prev[i],prev[(i+1)%18],curr[(i+1)%18],curr[i]))
   prev=curr
 def pw(co):
  z=co.z;side='Left' if co.x>=0 else 'Right'
  if z>=.86:return {'Hips':1}
  if z>=.75:t=(z-.75)/.11;return {'Hips':t,side+'UpLeg':1-t}
  t=max(0,min(1,(z-.44)/.12));return {side+'UpLeg':t,side+'Leg':1-t}
 add(mesh('Tailored branched trousers',vs,fs,pants,uv),pw)
 loft('Waistband under floating hem',[(.976,.164,.096,0),(1.006,.164,.096,0),(1.006,.150,.083,0),(.981,.150,.083,0)],pants,rigid('Hips'),32)
 # Few structurally meaningful garment details rather than shape-noise.
 if not fem:
  for z in [1.09,1.21,1.32,1.40]:add(ell('Metal shirt button',(0,-(.119 if z<1.34 else .099),z),(.006,.003,.006),M['metal'],10,6),torso_w)
 else:
  add(box('Knit label',(.118,-.125,1.015),(.025,.003,.012),M['trim'],.001),torso_w)
 # Join, apply transforms, map once, clean topology.
 body=join(parts,sex+'_custom_topology');bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');body.location=(0,0,0)
 for v in body.data.vertices:v.co=stylize(v.co)
 import bmesh
 bm=bmesh.new();bm.from_mesh(body.data);bmesh.ops.dissolve_degenerate(bm,dist=1e-7,edges=list(bm.edges));bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free()
 body.shape_key_add(name='Basis');key=body.shape_key_add(name='SleepLids')
 # Material-based eye geometry closure; no global head scaling.
 eyes={M[x] for x in ['white','iris','pupil']};ids=set()
 for f in body.data.polygons:
  if body.data.materials[f.material_index] in eyes:ids.update(f.vertices)
 eye_z=stylize((0,0,1.646)).z
 for i in ids:key.data[i].co.z=eye_z+(key.data[i].co.z-eye_z)*.055
 body.parent=arm;mod=body.modifiers.new('21 bone garment deformation','ARMATURE');mod.object=arm
 # Source skeleton kept, clips rebuilt below with unit head transform.
 return arm,body
chars={sex:make(sex) for sex in ['female','male']}
# Rebuild original five actions against V3 mesh and retain NLA export.
for sex,(arm,body) in chars.items():
 arm.animation_data_clear();arm.animation_data_create()
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  act=bpy.data.actions.new(sex+'_V3_'+kind);arm.animation_data.action=act
  for frame in [1,30,60]:
   bpy.context.scene.frame_set(frame);pose(arm,kind)
   for pb in arm.pose.bones:
    pb.rotation_mode='QUATERNION';pb.keyframe_insert(data_path='location',frame=frame);pb.keyframe_insert(data_path='rotation_quaternion',frame=frame);pb.keyframe_insert(data_path='scale',frame=frame)
  track=arm.animation_data.nla_tracks.new();track.name=kind;track.strips.new(kind,1,act);track.mute=True;arm.animation_data.action=None
 keys=body.data.shape_keys;keys.animation_data_create()
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  act=bpy.data.actions.new(sex+'_V3_'+kind+'_lids');keys.animation_data.action=act
  for frame in [1,60]:keys.key_blocks['SleepLids'].value=1 if kind=='Sleep_Bed' else 0;keys.key_blocks['SleepLids'].keyframe_insert(data_path='value',frame=frame)
  tr=keys.animation_data.nla_tracks.new();tr.name=kind;tr.strips.new(kind,1,act);tr.mute=True;keys.animation_data.action=None
 keys.key_blocks['SleepLids'].value=0
 for tr in arm.animation_data.nla_tracks:tr.mute=False
 for tr in keys.animation_data.nla_tracks:tr.mute=False
 pose(arm,'Idle');bpy.context.scene.frame_set(1)
 bpy.ops.object.select_all(action='DESELECT');arm.select_set(True);body.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(P/f'exports/{sex}_rigged.glb'),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_yup=True,export_apply=False)
 for tr in arm.animation_data.nla_tracks:tr.mute=True
 for tr in keys.animation_data.nla_tracks:tr.mute=True
 pose(arm,'Idle')
# Scenery remains exactly V2. Relative paths are packed into V3, no V2 writes.
bpy.context.scene.render.threads=8;bpy.context.scene.cycles.samples=24
bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(P/'blender_realtime_sample_v3.blend'))
print('V3_BUILD_DONE',flush=True)
