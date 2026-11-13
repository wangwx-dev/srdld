from PIL import Image,ImageDraw,ImageFont,ImageOps
from pathlib import Path
import json,hashlib,shutil
P=Path(__file__).resolve().parents[1];R=P/'renders';font='/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'
F=lambda n:ImageFont.truetype(font,n)
BG=(239,235,224);INK=(39,54,54);GRAY=(83,96,92)
def board(title,subtitle):
 im=Image.new('RGB',(1920,1080),BG);d=ImageDraw.Draw(im);d.text((38,20),title,font=F(32),fill=INK);d.text((40,67),subtitle,font=F(19),fill=GRAY);return im,d
def fit(im,rect):
 x,y,w,h=rect;image=ImageOps.contain(im.convert('RGB'),(w,h),Image.Resampling.LANCZOS);return image,(x+(w-image.width)//2,y+(h-image.height)//2)
def panel(out,path,rect,crop=None):
 a=Image.open(path)
 if crop:a=a.crop(crop)
 a,pos=fit(a,rect);out.paste(a,pos)
# Turntable review board with real pixel crops and a real topology pass.
audit=json.loads((P/'evidence/build_audit.json').read_text());im,d=board('01  双角色 / 造型、拓扑与骨骼实测','Blender 4.5.3 · 原创低模网格与面部纹理 · 非 AI 图片 · 真实 Cycles 渲染')
panel(im,R/'characters_front.png',(20,120,690,800),(410,0,1510,1080));panel(im,R/'characters_iso.png',(710,120,690,800),(330,0,1590,1080))
# Frontal face crop uses original render pixels, not synthetic detail.
panel(im,R/'characters_front.png',(1420,120,475,320),(560,30,1370,325));panel(im,R/'characters_topology.png',(1420,475,475,425),(410,0,1510,1080))
d.text((60,930),'正面造型',font=F(24),fill=INK);d.text((770,930),'45° 斜俯视',font=F(24),fill=INK);d.text((1440,930),'五官放大 / 真实拓扑叠加',font=F(22),fill=INK)
d.text((40,995),'女 4,504 tris / 1,452 quads    男 4,668 tris / 1,507 quads    每套 21 骨骼 · 5 条动作',font=F(24),fill=INK);im.save(R/'01_characters_turntable.png')
# Contact pose sheet uses unretouched full scene renders.
im,d=board('03  同一房间的生活姿态实拍','四幅均来自同一 .blend 与同一人型骨架；不是贴图替身。接触细节另见 qc/ 放大图。')
for i,(file,label) in enumerate([('pose_sleep.png','Sleep_Bed / 躺床'),('pose_read.png','Read_Book / 持书'),('pose_pet.png','Pet_Cat / 逗猫'),('pose_exit.png','Idle / 门前')]):
 x=(i%2)*960;y=108+(i//2)*480;panel(im,R/file,(x+10,y,940,430));d.text((x+35,y+427),label,font=F(23),fill=INK)
im.save(R/'03_room_poses_sheet.png')
# All four raw images are retained: Blender circle/checker vs actual Godot 4x4 Bayer.
im,d=board('04  方案二 / 圆形 Dither 镂空遮挡','上：Blender Cycles 真实透明网点材质。下：Godot 4.5.1 实际 OpenGL 渲染，4×4 Bayer + 主角深度门控。')
for i,(file,label) in enumerate([('occlusion_before.png','Blender / 关闭'),('occlusion_after.png','Blender / 开启'),('godot_occlusion_before.png','Godot / 关闭'),('godot_occlusion_after.png','Godot / 开启')]):
 x=(i%2)*960;y=108+(i//2)*480;panel(im,R/file,(x+10,y,940,420));d.text((x+35,y+421),label,font=F(23),fill=INK)
im.save(R/'04_dither_occlusion_preview.png')
# Before source is an actual previous game screenshot, explicitly not an equal-condition benchmark.
before=Path('/workspace/game-delivery-021b58d/02_room_sit.png');shutil.copy(before,P/'evidence/old_game_room_021b58d.png')
im,d=board('06  旧版实机 / 本版实时资产样板','按可见地板宽度归一到相近屏幕占幅；旧图与新场景的房间尺寸、照明及相机并不相同。')
panel(im,before,(20,140,920,820),(165,130,1110,720));panel(im,R/'02_room_isometric_sit.png',(980,140,920,820),(350,0,1570,1080))
d.text((60,975),'旧版 Godot 实机截图（021b58d）',font=F(25),fill=INK);d.text((1010,975),'本版 Blender 样板（尚未整合游戏）',font=F(25),fill=INK)
im.save(R/'06_before_after_comparison.png')
# Contact proof crops: intentionally no paint-over, interpolation only.
for name,src,crop in [('face_detail','characters_front.png',(500,0,1420,470)),('desk_contact','02_room_isometric_sit.png',(1070,470,1460,810)),('bed_contact','pose_sleep.png',(580,370,1060,715)),('reading_contact','pose_read.png',(1070,470,1460,810)),('cat_contact','pose_pet.png',(800,590,1230,920)),('cloth_uv_detail','characters_iso.png',(700,300,1160,750))]:
 image=Image.open(R/src).crop(crop);image.resize((image.width*2,image.height*2),Image.Resampling.LANCZOS).save(P/'qc'/f'{name}_200pct.png')
# Small overview for fast parent review.
im=Image.new('RGB',(1920,1080),BG);d=ImageDraw.Draw(im)
for i,n in enumerate(['01_characters_turntable.png','02_room_isometric_sit.png','03_room_poses_sheet.png','04_dither_occlusion_preview.png','05_city_overview_isometric.png','06_before_after_comparison.png']):panel(im,R/n,((i%3)*640,(i//3)*540,640,540))
im.save(P/'REVIEW_OVERVIEW.jpg',quality=93)
(P/'evidence/before_image_provenance.json').write_text(json.dumps({'source':str(before),'sha256':hashlib.sha256(before.read_bytes()).hexdigest(),'note':'actual old game screenshot; crop excludes HUD; floor footprint normalized, not a metric or same-condition comparison'},indent=2))
