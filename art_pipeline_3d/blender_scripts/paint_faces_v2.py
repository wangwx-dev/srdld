from PIL import Image,ImageDraw,ImageFilter
from pathlib import Path
P=Path(__file__).resolve().parents[1]/'textures'
for sex in ['female','male']:
 base=(232,183,159) if sex=='female' else (210,161,133)
 im=Image.new('RGB',(2048,2048),base)
 layer=Image.new('RGBA',im.size);d=ImageDraw.Draw(layer)
 for x in [807,1241]:d.ellipse((x-90,1260,x+90,1420),fill=(232,107,113,90))
 im=Image.alpha_composite(im.convert('RGBA'),layer.filter(ImageFilter.GaussianBlur(30)));d=ImageDraw.Draw(im)
 for cx in [862,1186]:
  d.ellipse((cx-89,1005,cx+89,1233),fill=(180,115,93))
  d.ellipse((cx-82,1017,cx+82,1220),fill=(255,245,228))
  d.ellipse((cx-48,1019,cx+48,1216),fill=(110,121,94) if sex=='female' else (125,90,58))
  d.ellipse((cx-29,1032,cx+29,1200),fill=(43,50,47))
  d.ellipse((cx-29,1033,cx-5,1071),fill=(255,255,244));d.ellipse((cx+14,1153,cx+27,1175),fill=(227,230,198))
  d.arc((cx-88,1002,cx+88,1232),180,345,fill=(66,46,38),width=12)
  d.arc((cx-77,917,cx+77,969),185,335,fill=(89,58,43),width=15)
 d.arc((993,1332,1055,1380),5,165,fill=(184,115,93),width=6)
 d.arc((958,1480,1090,1550),5,175,fill=(151,79,75),width=11)
 d.arc((990,1526,1060,1554),0,180,fill=(218,139,127),width=5)
 im.convert('RGB').save(P/f'{sex}_face.png')
