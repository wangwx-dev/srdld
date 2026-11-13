from PIL import Image,ImageDraw,ImageFont,ImageFilter
from pathlib import Path
import math,random
P=Path(__file__).resolve().parents[1]/'textures';P.mkdir(exist_ok=True)
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def F(n):return ImageFont.truetype(font,n)
for sex in ['female','male']:
 im=Image.new('RGB',(1024,1024),(197,145,118) if sex=='male' else (226,177,151));d=ImageDraw.Draw(im)
 # Cylindrical portrait; eyes on front sector, expression deliberately quiet.
 for cx in [431,593]:
  d.ellipse((cx-49,494,cx+49,551),fill=(151,107,89))
  d.ellipse((cx-43,501,cx+43,547),fill=(234,226,210))
  d.ellipse((cx-16,500,cx+16,548),fill=(78,88,75));d.ellipse((cx-8,507,cx+8,542),fill=(27,33,31));d.ellipse((cx-5,511,cx,517),fill=(248,237,217))
  d.arc((cx-45,494,cx+45,550),180,355,fill=(65,49,43),width=6)
  d.line((cx-38,471,cx,467,cx+35,473),fill=(77,57,44),width=6)
 d.line((498,606,512,611,527,605),fill=(164,104,83),width=4)
 d.line((479,684,512,689,545,683),fill=(139,78,73),width=8);d.arc((488,687,539,713),0,180,fill=(175,114,100),width=3)
 # freckles, understated blush
 rng=random.Random(13)
 for x in [417,600]:
  for j in range(7):
   xx=x+rng.randint(-25,25); yy=rng.randint(574,600);d.ellipse((xx,yy,xx+2,yy+2),fill=(171,116,94))
 im.save(P/f'{sex}_face.png')
# Author-created screen texture, not generated imagery.
im=Image.new('RGB',(1024,640),(21,30,44));d=ImageDraw.Draw(im);d.rounded_rectangle((25,22,998,80),12,fill=(38,54,73));d.text((48,35),'CREATOR STUDIO / DAILY LOG',font=F(26),fill=(223,234,230))
d.rounded_rectangle((28,108,665,437),14,fill=(52,78,84));d.rectangle((53,136,639,405),fill=(113,143,137));d.polygon([(54,405),(200,210),(332,315),(470,184),(638,405)],fill=(209,195,161));d.text((76,153),'A quiet day in the city',font=F(27),fill=(244,238,216))
d.rounded_rectangle((695,108,993,437),14,fill=(33,46,62));d.text((718,131),'THIS WEEK',font=F(23),fill=(146,195,182))
for k,w in enumerate([180,225,151,198,236]):
 y=190+k*41;d.rectangle((720,y,720+w,y+15),fill=(98,157,143))
d.text((40,464),'Timeline  |  Room tour - draft 03',font=F(23),fill=(205,213,213))
for k in range(12):d.rounded_rectangle((40+k*78,514,110+k*78,596),6,fill=(78+k*5,120+k*3,132))
im.save(P/'monitor_content.png')
# Book covers, page lines and weave tint are author-made complements to CC0 maps.
im=Image.new('RGB',(512,512),(217,203,169));d=ImageDraw.Draw(im)
for y in range(8,512,8):d.line((0,y,512,y),fill=(174,159,132))
im.save(P/'pages.png')
