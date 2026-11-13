import bpy,json,struct,math,collections
from pathlib import Path
P=Path(__file__).resolve().parents[1];results={}
for path in sorted((P/'exports').glob('*.glb')):
 blob=path.read_bytes();n,t=struct.unpack_from('<II',blob,12);doc=json.loads(blob[20:20+n]);res={'bytes':len(blob),'gltf_version':doc['asset']['version'],'mesh_count':len(doc.get('meshes',[])),'skins':len(doc.get('skins',[])),'animations':[a.get('name','unnamed') for a in doc.get('animations',[])],'embedded_images':len(doc.get('images',[])),'external_image_uris':[i['uri'] for i in doc.get('images',[]) if 'uri' in i],'glb_triangles':sum(doc['accessors'][p['indices']]['count']//3 for m in doc.get('meshes',[]) for p in m['primitives']),'skin_joints':[[doc['nodes'][j].get('name') for j in s['joints']] for s in doc.get('skins',[])]}
 res['animation_motion']={}
 bin_header=20+n;bin_size,bin_type=struct.unpack_from('<II',blob,bin_header);binary=blob[bin_header+8:bin_header+8+bin_size]
 def accessor_values(index):
  acc=doc['accessors'][index];view=doc['bufferViews'][acc['bufferView']];components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[acc['type']];code={5120:'b',5121:'B',5122:'h',5123:'H',5125:'I',5126:'f'}[acc['componentType']];size=struct.calcsize(code);offset=view.get('byteOffset',0)+acc.get('byteOffset',0);stride=view.get('byteStride',components*size)
  return [struct.unpack_from('<'+code*components,binary,offset+i*stride) for i in range(acc['count'])]
 mesh_counts=[];mesh_valid=[];mesh_dedup=[];degen_total=0;duplicate_total=0
 for gm in doc.get('meshes',[]):
  count=0;valid=0;duplicates=0
  for primitive in gm['primitives']:
   positions=accessor_values(primitive['attributes']['POSITION']);indices=[x[0] for x in accessor_values(primitive['indices'])] if 'indices' in primitive else list(range(len(positions)))
   count+=len(indices)//3
   duplicates+=sum(c-1 for c in collections.Counter(tuple(sorted(indices[i:i+3])) for i in range(0,len(indices),3)).values())
   for i in range(0,len(indices),3):
    aa,bb,cc=[positions[x] for x in indices[i:i+3]];u=[bb[k]-aa[k] for k in range(3)];vv=[cc[k]-aa[k] for k in range(3)];cross=[u[1]*vv[2]-u[2]*vv[1],u[2]*vv[0]-u[0]*vv[2],u[0]*vv[1]-u[1]*vv[0]]
    if sum(x*x for x in cross)>1e-18:valid+=1
  mesh_counts.append(count);mesh_valid.append(valid);mesh_dedup.append(count-duplicates);degen_total+=count-valid;duplicate_total+=duplicates
 res['glb_near_zero_area_triangles_threshold_squared_cross_1e18']=degen_total;res['glb_duplicate_index_faces']=duplicate_total;res['expected_blender_reimport_triangles']=sum(mesh_dedup[n['mesh']] for n in doc.get('nodes',[]) if 'mesh' in n);res['glb_scene_instance_triangles']=sum(mesh_counts[n['mesh']] for n in doc.get('nodes',[]) if 'mesh' in n);res['glb_valid_scene_instance_triangles']=sum(mesh_valid[n['mesh']] for n in doc.get('nodes',[]) if 'mesh' in n);res['triangle_accounting_note']='glb_triangles counts unique mesh index triplets; scene-instance counts include reused meshes. Near-zero-area counts are diagnostic only. Blender removes duplicate indexed faces; expected reimport count subtracts those, not the tiny-area faces.'
 for anim in doc.get('animations',[]):
  moving=0
  for sampler in anim['samplers']:
   acc=doc['accessors'][sampler['output']];view=doc['bufferViews'][acc['bufferView']];components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[acc['type']]
   offset=view.get('byteOffset',0)+acc.get('byteOffset',0);stride=view.get('byteStride',components*4)
   vals=[struct.unpack_from('<'+'f'*components,binary,offset+i*stride) for i in range(acc['count'])]
   if any(max(v[j] for v in vals)-min(v[j] for v in vals)>1e-6 for j in range(components)):moving+=1
  res['animation_motion'][anim.get('name','unnamed')]={'nonconstant_channels':moving,'genuine_motion_not_just_hold':moving>0}
 bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=str(path));arms=[o for o in bpy.data.objects if o.type=='ARMATURE'];helpers={pb.custom_shape for arm in arms for pb in arm.pose.bones if pb.custom_shape};res['blender_bone_display_helpers_excluded']=[{'name':o.name,'vertices':len(o.data.vertices),'faces':len(o.data.polygons),'purpose':'Blender importer-created pose-bone custom shape; not an exported character mesh'} for o in helpers];meshes=[o for o in bpy.data.objects if o.type=='MESH' and o not in helpers];res['reimported_bones']={a.name:len(a.data.bones) for a in arms};res['reimported_triangles']=sum(len(o.data.loop_triangles) or (o.data.calc_loop_triangles() or len(o.data.loop_triangles)) for o in meshes);res['all_meshes_uv']=all(o.data.uv_layers for o in meshes);res['all_images_loaded']=all(i.size[0]>0 and len(i.pixels)>0 for i in bpy.data.images if i.type!='RENDER_RESULT');res['finite_geometry']=all(all(math.isfinite(c) for c in v.co) for o in meshes for v in o.data.vertices)
 if arms:
  res['unweighted_vertices']=sum(not any(g.weight>0 for g in v.groups) for o in meshes for v in o.data.vertices);res['weight_sum_max_error']=max(abs(1-sum(g.weight for g in v.groups)) for o in meshes for v in o.data.vertices)
  res['bone_parent_hierarchy']={b.name:b.parent.name if b.parent else None for b in arms[0].data.bones};res['action_frame_checks']=[]
  for act in bpy.data.actions:
   a=arms[0];a.animation_data_create();a.animation_data.action=act
   for frame in [1,25,49]:
    bpy.context.scene.frame_set(frame);dg=bpy.context.evaluated_depsgraph_get();finite=all(all(math.isfinite(x) for x in row) for p in a.pose.bones for row in p.matrix);res['action_frame_checks'].append({'action':act.name,'frame':frame,'finite_bone_matrices':finite})
 res['passed_transport_checks']=res['finite_geometry'] and res['all_images_loaded'] and not res['external_image_uris'] and res['reimported_triangles']==res['expected_blender_reimport_triangles'] and (not arms or (res['unweighted_vertices']==0 and res['weight_sum_max_error']<1e-5));results[path.name]=res
(P/'evidence/glb_reimport.json').write_text(json.dumps(results,indent=2));print(json.dumps({k:{'tris':v['glb_triangles'],'actions':v['animations'],'images':v['embedded_images']} for k,v in results.items()},indent=2))
