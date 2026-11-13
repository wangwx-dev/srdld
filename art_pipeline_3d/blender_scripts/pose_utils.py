import bpy,math
from mathutils import Vector,Matrix

def stylize(co):
 x,y,z=co
 if z<=.95: zz=z; xx=x*1.06; yy=y
 elif z<1.49:
  zz=.95+(z-.95)*(.39/.54)
  shoulder=math.exp(-((z-1.40)/.13)**2)
  xx=x*(1.12-.28*shoulder);yy=y*(1.04 if abs(x)<.2 else 1)
 else:zz=1.34+(z-1.49)*1.075;xx=x*1.39;yy=y*1.28
 return Vector((xx,yy,zz))

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
 # Preserve length: matrices preserve skin volume and use target vectors, not bone stretching.
 for pb in arm.pose.bones:
  h,t=pos[pb.name]
  if kind!='Sleep_Bed':h=stylize(h);t=stylize(t)
  rest=pb.bone.tail_local-pb.bone.head_local
  if pb.name=='Head':t=h+(t-h).normalized()*rest.length
  q=rest.rotation_difference(t-h);pb.matrix=Matrix.Translation(h)@q.to_matrix().to_4x4()@pb.bone.matrix_local.to_3x3().to_4x4()@Matrix.Diagonal((1,(t-h).length/rest.length,1,1))
  bpy.context.view_layer.update()
