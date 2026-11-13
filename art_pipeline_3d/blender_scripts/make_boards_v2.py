from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import json
P=Path(__file__).resolve().parents[1];R=P/'renders';V1=P.parent/'blender-realtime-sample'/'renders'
FONT='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
def f(n):return ImageFont.truetype(FONT,n)
def panel(im,path,box,crop=None):
 img=Image.open(path).convert('RGB')
 if crop:img=img.crop(crop)
 fitted=ImageOps.contain(img,(box[2]-box[0],box[3]-box[1]),Image.Resampling.LANCZOS)
 im.paste(fitted,(box[0]+(box[2]-box[0]-fitted.width)//2,box[1]+(box[3]-box[1]-fitted.height)//2))
def base(title,size=(2400,1600)):
 im=Image.new('RGB',size,'#f3efe5');d=ImageDraw.Draw(im);d.text((45,25),title,font=f(40),fill='#243a3a');return im,d
A=json.loads((P/'evidence/build_audit.json').read_text())['characters']
im,d=base('01  双角色精修 / 同一网格的正面、45°、面部与拓扑')
for text,x,y in [('正面 / 自然斜肩与连续裤裆',45,95),('固定 45° 斜俯视',1230,95),('正面原图面部 200% 放大（非 AI）',45,855),('真实三角拓扑线框 + 21 骨骼',1230,855)]:d.text((x,y),text,font=f(28),fill='#435353')
panel(im,R/'characters_front.png',(30,140,1180,800));panel(im,R/'characters_iso.png',(1220,140,2370,800))
# Exactly 2x crops from the 1920px front render.
front=Image.open(R/'characters_front.png').convert('RGB')
for sex,x,crop in [('女',130,(550,115,770,355)),('男',670,(1150,115,1370,355))]:
 face=front.crop(crop).resize((440,480),Image.Resampling.NEAREST);im.paste(face,(x,930));d.text((x,1420),sex+' / 2K 手绘五官贴图',font=f(24),fill='#435353')
panel(im,R/'characters_topology.png',(1220,900,2370,1510))
d.text((45,1530),f"女 {A['female']['triangles']:,} tris  |  男 {A['male']['triangles']:,} tris  |  每人 21 骨骼、5 生活动作 + 睡眠闭眼 Morph",font=f(28),fill='#243a3a')
im.save(R/'01_characters_turntable_v2.png')
im,d=base('03  生活动作接触复测 / 均为当前 Blender 网格真实渲染')
for name,title,box in [('pose_sleep.png','Sleep_Bed / 枕面、鞋跟与床面',(35,140,1185,770)),('pose_read.png','Read_Book / 双手持书，椅背留空',(1215,140,2365,770)),('pose_pet.png','Pet_Cat / 左手猫头、右手背部',(35,900,1185,1530)),('pose_exit.png','Idle / 门前站姿与双脚落地',(1215,900,2365,1530))]:
 d.text((box[0],box[1]-45),title,font=f(28),fill='#435353');panel(im,R/name,box)
im.save(R/'03_room_poses_sheet_v2.png')
im,d=base('05  V1 / V2 同尺度对照 — 相同正交相机与同等图片缩放',(2400,1700))
d.text((55,95),'V1 / 修改前',font=f(34),fill='#815742');d.text((1255,95),'V2 / 当前精修',font=f(34),fill='#315f55')
panel(im,V1/'characters_front.png',(35,155,1185,770),crop=(400,110,1520,710));panel(im,R/'characters_front.png',(1215,155,2365,770),crop=(400,110,1520,710))
panel(im,V1/'02_room_isometric_sit.png',(35,835,1185,1485));panel(im,R/'02_room_isometric_sit_v2.png',(1215,835,2365,1485))
d.text((45,1510),'角色：头身比例 / 肩袖 / 顺滑胯部 / 圆头运动鞋 / 2K 五官',font=f(30),fill='#243a3a')
d.text((45,1570),'房间：裁掉低墙交叠黑块 / 书架移出床头遮挡区 / 日间暖光 / 中性金属',font=f(30),fill='#243a3a')
im.save(R/'05_v1_vs_v2_comparison.png')
