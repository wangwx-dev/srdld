import requests,json,hashlib,concurrent.futures,time
from pathlib import Path
P=Path(__file__).resolve().parents[1]
UA='WangWenxu-BlenderRealtime-ArtPrototype/1.0 (offline CC0 game-art evaluation)'
s=requests.Session();s.headers['User-Agent']=UA
slugs=['wood_floor','painted_plaster_wall','denim_fabric','dark_wood','metal_plate','floor_tiles_08','asphalt_03','grass_ground','cotton_jersey','rough_linen','brown_leather']
manifest={'user_agent':UA,'license':'CC0-1.0','license_url':'https://polyhaven.com/license','files':[],'assets':{}}
jobs=[]
for slug in slugs:
 data=s.get('https://api.polyhaven.com/files/'+slug,timeout=60).json();(P/'evidence'/f'{slug}_files.json').write_text(json.dumps(data,indent=2))
 info=s.get('https://api.polyhaven.com/info/'+slug,timeout=60).json();manifest['assets'][slug]={'page':'https://polyhaven.com/a/'+slug,'info':info}
 print(slug,list(data),flush=True)
 for kind in ['Diffuse','Rough','nor_gl']:
  entry=data[kind]['2k'];f=entry.get('jpg',entry.get('png'));jobs.append((slug,kind,f))
# Full real furniture, keep GLTF dependency graph and verify each file too.
slug='modern_coffee_table_01';data=s.get('https://api.polyhaven.com/files/'+slug).json();(P/'evidence'/f'{slug}_files.json').write_text(json.dumps(data,indent=2));f=data['gltf']['2k']['gltf'];jobs.append((slug,'gltf',f))
for path,entry in f.get('include',{}).items():jobs.append((slug,'dependency:'+path,entry))
# HDRI already verified fresh from API
slug='studio_small_09';data=s.get('https://api.polyhaven.com/files/'+slug).json();f=data['hdri']['1k']['hdr'];jobs.append((slug,'hdri',f))
def run(job):
 slug,kind,f=job;url=f['url'];dest=P/'textures'/slug/(kind.split(':',1)[1] if kind.startswith('dependency:') else url.rsplit('/',1)[-1]);dest.parent.mkdir(parents=True,exist_ok=True)
 if not dest.exists() or hashlib.md5(dest.read_bytes()).hexdigest()!=f['md5']:
  r=requests.get(url,headers={'User-Agent':UA},timeout=180);r.raise_for_status();dest.write_bytes(r.content)
 md5=hashlib.md5(dest.read_bytes()).hexdigest();assert md5==f['md5'],url
 print('OK',slug,kind,dest.stat().st_size,flush=True)
 return {'asset':slug,'map':kind,'resolution':'1k' if kind=='hdri' else '2k','path':str(dest.relative_to(P)),'url':url,'md5_expected':f['md5'],'md5_actual':md5,'md5_match':True,'bytes':dest.stat().st_size,'license':'CC0-1.0'}
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
 manifest['files']=list(ex.map(run,jobs))
(P/'asset_manifest.json').write_text(json.dumps(manifest,indent=2))
