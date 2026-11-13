from pathlib import Path
p=Path(__file__).resolve().parent/'build_sample.py';s=p.read_text()
s=s.replace('(1.49,.038,.045,-.018),(1.515,.068,.068,-.012),(1.54,.088,.083,0)','(1.49,.058,.052,-.012),(1.515,.082,.074,-.007),(1.54,.101,.088,0)')
a=s.index(' # Sculpted hair cap')
s=s[:a]+''' # Two skinned eyelid patches: hidden under hair while awake; morph onto the eyes for Sleep_Bed.
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
''' +s[a:]
a=s.index(' # Store manual refined weights')
s=s[:a]+''' # Morph only the eyelid geometry; the original painted face remains unchanged.
 lid_indices=set()
 for poly in body.data.polygons:
  if '_sleep_' in body.data.materials[poly.material_index].name:lid_indices.update(poly.vertices)
 basis=body.shape_key_add(name='Basis');closed=body.shape_key_add(name='SleepLids')
 for idx in lid_indices:
  basis.data[idx].co.z=stylize((0,0,1.69)).z
  basis.data[idx].co.y+=.055
''' +s[a:]
a=s.index('# Book accessory')
s=s[:a]+'''# Merge eyelid morph clips into the corresponding skeleton NLA track names on GLB export.
for sex,(arm,body) in chars.items():
 keys=body.data.shape_keys;keys.animation_data_create()
 for kind in ['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat']:
  act=bpy.data.actions.new(sex+'_Lids_'+kind);keys.animation_data.action=act
  for frame in [1,25,49]:
   keys.key_blocks['SleepLids'].value=1.0 if kind=='Sleep_Bed' else 0.0
   keys.key_blocks['SleepLids'].keyframe_insert(data_path='value',frame=frame)
  track=keys.animation_data.nla_tracks.new();track.name=kind;track.strips.new(kind,1,act);track.mute=True
 keys.animation_data.action=None;keys.key_blocks['SleepLids'].value=0
''' +s[a:]
p.write_text(s)
p=p.parent/'render_sample.py';s=p.read_text().replace("a.location=loc;a.rotation_euler=rot;pose(a,kind)","a.location=loc;a.rotation_euler=rot\n if b.data.shape_keys:\n  keys=b.data.shape_keys;keys.animation_data.action=None\n  for track in keys.animation_data.nla_tracks:track.mute=True\n  keys.key_blocks['SleepLids'].value=1 if kind=='Sleep_Bed' else 0\n pose(a,kind)")
p.write_text(s)
