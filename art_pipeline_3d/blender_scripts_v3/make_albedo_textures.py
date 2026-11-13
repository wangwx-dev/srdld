from pathlib import Path
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parents[1];y,x=np.mgrid[:512,:512]/512;rng=np.random.default_rng(31)
colors={'Skin_F':((.69,.405,.278),'skin'),'Skin_M':((.48,.26,.16),'skin'),'Hair_chestnut':((.055,.019,.012),'hair'),'Hair_espresso':((.018,.014,.012),'hair'),'Knit_sage':((.105,.27,.225),'knit'),'Cotton_midnightblue':((.045,.12,.23),'cotton'),'Denim_indigo':((.035,.065,.115),'denim'),'Chinos_slate':((.17,.20,.19),'denim'),'Rubber_cupsole':((.69,.68,.59),'rubber'),'Canvas_shoe':((.20,.22,.205),'canvas'),'Collar_binding':((.46,.49,.39),'knit')}
for name,(col,typ) in colors.items():
 if typ=='hair':val=1+.13*np.sin(x*2*np.pi*85+np.sin(y*2*np.pi*3)*.9)+.05*np.sin(x*2*np.pi*191+y*10)
 elif typ=='denim':val=1+.07*np.sin((x+y)*2*np.pi*70)+rng.normal(0,.016,x.shape)
 elif typ in ['cotton','knit','canvas']:val=1+.045*np.sin(x*2*np.pi*85)*np.cos(y*2*np.pi*85)+rng.normal(0,.015,x.shape)
 else:val=1+rng.normal(0,.006,x.shape)
 linear=np.clip(np.array(col)[None,None,:]*val[:,:,None],0,1);rgb=np.where(linear<.0031308,linear*12.92,1.055*linear**(1/2.4)-.055)
 Image.fromarray(np.uint8(np.clip(rgb,0,1)*255)).save(P/'textures'/f'{name}_albedo.png')
