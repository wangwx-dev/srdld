from pathlib import Path
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1]/'textures';rng=np.random.default_rng(8401)
y,x=np.mgrid[:512,:512]/512
for typ,rough in [('skin',.46),('hair',.45),('knit',.92),('cotton',.90),('denim',.88),('rubber',.39),('canvas',.54)]:
 if typ=='hair':h=.5*np.sin(x*2*np.pi*85+np.sin(y*2*np.pi*3)*.9)+.20*np.sin(x*2*np.pi*191+y*10)
 elif typ=='denim':h=.35*np.sin((x+y)*2*np.pi*70)+.12*np.sin(x*2*np.pi*128)*np.sin(y*2*np.pi*128)
 elif typ in ['cotton','canvas','knit']:h=.23*np.sin(x*2*np.pi*85)+.23*np.sin(y*2*np.pi*85)+(.18*np.cos((x*85%1-.5)*4+y*2*np.pi*42) if typ=='knit' else 0)
 else:h=rng.normal(0,.10 if typ=='skin' else .06,(512,512))
 dy,dx=np.gradient(h);strength=1.6 if typ=='hair' else .65
 n=np.stack([-dx*strength,dy*strength,np.ones_like(h)],-1);n/=np.linalg.norm(n,axis=-1,keepdims=True)
 Image.fromarray(np.uint8((n*.5+.5)*255)).save(P/f'{typ}_normal.png')
 r=np.clip(rough+h*.012,rough-.018,rough+.018);Image.fromarray(np.uint8(r*255)).save(P/f'{typ}_roughness.png')
