from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
P=Path(__file__).resolve().parents[1];R=P/'renders'
FONT='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
def font(n):return ImageFont.truetype(FONT,n)
def base(title,sub,size):
 im=Image.new('RGB',size,'#e8e6dd');d=ImageDraw.Draw(im);d.text((40,20),title,font=font(38),fill='#213b3c');d.text((40,75),sub,font=font(21),fill='#50605c');return im,d
def panel(im,name,box):
 img=Image.open(R/name).convert('RGB');img=ImageOps.contain(img,(box[2]-box[0],box[3]-box[1]));im.paste(img,((box[0]+box[2]-img.width)//2,(box[1]+box[3]-img.height)//2))
im,d=base('01  角色 V3 / 大形体、穿戴层次、分材质','全部原始画面由 Blender 4.5.3 Cycles 真实渲染；下方为原图裁切/排版，不使用 AI 图像。',(3200,2400))
for name,title,x in [('characters_front.png','正视 / 平直悬空衣摆、独立裤裆',30),('characters_iso.png','45° 斜俯 / 肩背与服装松量',1085),('characters_side.png','侧视 / 发束、鞋帮、衣缘厚度',2140)]:
 d.text((x,125),title,font=font(25),fill='#213b3c');panel(im,name,(x,170,x+1030,950))
front=Image.open(R/'characters_front.png').convert('RGB')
for label,x,crop in [('女 / 正面原像素 200%',40,(385,70,650,330)),('男 / 正面原像素 200%',590,(945,70,1210,330))]:
 d.text((x,975),label,font=font(24),fill='#213b3c');c=front.crop(crop);c=c.resize((c.width*2,c.height*2),Image.Resampling.NEAREST);im.paste(c,(x,1020))
d.text((1150,975),'针织/斜纹布料、金属扣、悬空折边与凹槽',font=font(25),fill='#213b3c');panel(im,'garment_detail.png',(1140,1020,3160,1560))
d.text((40,1605),'真实网格线框 / 21 骨骼保留，未用衣服内部肉体填体积',font=font(25),fill='#213b3c');panel(im,'characters_topology.png',(30,1660,1530,2360))
d.text((1590,1605),'鞋面 / 厚鞋底 / 鞋带与金属孔',font=font(25),fill='#213b3c');panel(im,'shoes_detail.png',(1580,1660,3160,2360))
im.save(R/'01_characters_v3_turntable.png')
im,d=base('02  V3 双角色 / 暖亮 V2 房间中的生活动作','Blender Cycles 真实实景；两套骨架均完成五动作接触数值复测。女角色示范四动作，门前男女同框。',(3000,2230))
for name,title,box in [('pose_sit.png','坐桌 / 手掌与键盘、袖口与椅背',(30,180,1480,1040)),('pose_sleep.png','仰躺 / 头骨不继承缩放，枕面与床面',(1520,180,2970,1040)),('pose_read.png','持书 / 手指轮廓与书页',(30,1160,1010,2110)),('pose_pet.png','逗猫 / 肘膝褶皱与接触',(1030,1160,2010,2110)),('pose_exit.png','门前过道 / 男女站姿与比例',(2030,1160,2970,2110))]:
 d.text((box[0],box[1]-45),title,font=font(25),fill='#213b3c');panel(im,name,box)
im.save(R/'02_room_v3_poses.png')
im,d=base('04  V2 → V3 / 同机位、同正交尺度、同灯光','V2 也重新用相同相机与灯光渲染；不是靠放大新版或变更打光制造对比。',(2800,2300))
for title,x in [('V2 / 修改前',30),('V3 / 当前',1430)]:d.text((x,125),title,font=font(31),fill='#213b3c')
for name,box in [('v2_front.png',(30,180,1370,1185)),('characters_front.png',(1430,180,2770,1185)),('v2_iso.png',(30,1240,1370,2245)),('characters_iso.png',(1430,1240,2770,2245))]:panel(im,name,box)
im.save(R/'04_v2_vs_v3_comparison.png')
