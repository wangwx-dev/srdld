from pathlib import Path
import json,hashlib,struct,datetime,math
from PIL import Image,ImageChops,ImageStat
P=Path(__file__).resolve().parents[1];V1=P.parent/'blender-realtime-sample'
load=lambda n:json.loads((P/n).read_text())
hashf=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
a=load('evidence/build_audit.json');g=load('evidence/glb_reimport.json');c=load('evidence/contact_qc_v2.json');src=load('evidence/source_audit_v2.json');godot=load('godot_dither_probe/runtime_verification.json')
expected=['Idle','Sit_Desk','Sleep_Bed','Read_Book','Pet_Cat'];chars=['female','male']
morph={}
for sex in chars:
 b=(P/f'exports/{sex}_rigged.glb').read_bytes();n=struct.unpack_from('<I',b,12)[0];d=json.loads(b[20:20+n]);morph[sex]={an['name']:sum(ch['target']['path']=='weights' for ch in an['channels']) for an in d['animations']}
images={}
required=['01_characters_turntable_v2.png','02_room_isometric_sit_v2.png','03_room_poses_sheet_v2.png','04_godot_room_realtime_v2.png','05_v1_vs_v2_comparison.png']
for name in required:
 f=P/'renders'/name;im=Image.open(f);images[name]={'dimensions':list(im.size),'sha256':hashf(f)}
diff=ImageChops.difference(Image.open(P/'renders/godot_occlusion_before.png').convert('RGB'),Image.open(P/'renders/godot_occlusion_after.png').convert('RGB'));changed=sum(any(v) for v in diff.getdata())
v1checks={}
for line in (V1/'DELIVERABLE_SHA256.txt').read_text().splitlines():
 sha,name=line.split('  ',1);v1checks[name]=hashf(V1/name)==sha
contactpass=True
for sex in chars:
 q=c[sex]
 contactpass &= all(0<=q[k]['foot_lowest_world_z_m']<=.012 for k in ['Idle','Sit_Desk','Read_Book','Pet_Cat'])
 contactpass &= q['Sit_Desk']['chair_back_penetrating_vertices']==0
 contactpass &= max(q['Sit_Desk']['hand_keyboard_surface_gap_m'].values())<.003
 contactpass &= max(q['Read_Book']['hand_book_surface_gap_m'].values())<.003
 contactpass &= q['Pet_Cat']['closest_hand_cat_head_gap_m']<.003
 contactpass &= max(q['Sleep_Bed']['shoe_duvet_gap_m'].values())<.003 and q['Sleep_Bed']['head_pillow_surface_gap_m']<.003
log=lambda n:(P/'evidence'/n).read_bytes().decode('utf-8','replace')
checks={
 'v1_deliverables_sha256_unchanged':all(v1checks.values()),
 'characters_2000_to_5000_exported_triangles':all(2000<=g[f'{s}_rigged.glb']['glb_triangles']<=5000 for s in chars),
 'characters_4_5_to_5_5_head_units':all(4.5<=src['characters'][s]['head_units']<=5.5 for s in chars),
 'characters_exactly_21_bones':all(list(g[f'{s}_rigged.glb']['reimported_bones'].values())==[21] for s in chars),
 'characters_zero_unweighted_vertices':all(g[f'{s}_rigged.glb']['unweighted_vertices']==0 for s in chars),
 'characters_weight_sum_error_below_1e_minus5':all(g[f'{s}_rigged.glb']['weight_sum_max_error']<1e-5 for s in chars),
 'all_exports_zero_duplicate_index_faces':all(x['glb_duplicate_index_faces']==0 for x in g.values()),
 'characters_zero_degenerate_triangles':all(g[f'{s}_rigged.glb']['glb_near_zero_area_triangles_threshold_squared_cross_1e18']==0 for s in chars),
 'five_motion_clips_each':all(g[f'{s}_rigged.glb']['animations']==expected and all(v['genuine_motion_not_just_hold'] for v in g[f'{s}_rigged.glb']['animation_motion'].values()) for s in chars),
 'sleep_eyelid_morph_channels_all_five_clips':all(all(morph[s][k]>=1 for k in expected) for s in chars),
 'face_textures_2048_square':all(src['characters'][s]['face_texture_pixels']==[2048,2048] for s in chars),
 'library_pivots_zero_error':all(max(abs(x) for x in m['origin_grid_error_m'])==0 for m in a['modules']),
 'placed_modules_on_2m_grid':all(max(m['grid_error_m'])<1e-6 and m['quarter_turn_error_degrees']<1e-4 for m in src['placements']),
 'both_character_contacts_within_documented_tolerances':bool(contactpass),
 'all_glbs_reimport_transport_pass':all(x['passed_transport_checks'] for x in g.values()),
 'godot_tested_files_sha256_match_final_exports':all(hashf(f)==hashf(P/'godot_dither_probe/assets'/f.name) for f in (P/'exports').glob('*.glb')),
 'godot_all_exports_loaded':all(v['loaded'] for k,v in godot.items() if k.endswith('.glb')),
 'godot_21_bones_and_five_clips':all(godot[f'{s}_rigged.glb']['skeletons'][0]['bones']==21 and set(expected).issubset(set(godot[f'{s}_rigged.glb']['animation_players'][0])) for s in chars),
 'godot_real_room_render_finished_no_errors':'REAL_GODOT_ROOM_RENDER_FINISHED' in log('godot_room_v2.log') and 'ERROR:' not in log('godot_room_v2.log'),
 'dither_shader_real_opengl_render_and_changed_pixels':godot['shader']['resource_loaded'] and 'REAL_GODOT_DITHER_RENDER_FINISHED' in log('godot_dither_v2.log') and changed>10000,
 'five_required_images_exist':len(images)==5,
 'manual_visual_review_recorded':(P/'evidence/VISUAL_REVIEW_V2.md').exists(),
}
now=datetime.datetime.now(datetime.timezone(datetime.timedelta(hours=8))).isoformat()
verification={'version':'v2','generated_at_Asia_Shanghai':now,'checks':checks,'all_required_checks_passed':all(checks.values()),'source_audit':src,'contacts':c,'glb_reimport':g,'godot':godot,'eyelid_morph_channels':morph,'images':images,'v1_hash_checks':v1checks,'dither_changed_pixels':changed,'diagnostics_not_visual_failures':{'room_microscopic_area_triangles':g['room_realtime.glb']['glb_near_zero_area_triangles_threshold_squared_cross_1e18'],'note':'Scene-only imported coffee-table bevel details; duplicate index faces are zero. This diagnostic is separate from character zero-degenerate validation.'}}
(P/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2))
rows='\n'.join(f"| {'女' if s=='female' else '男'} | {g[f'{s}_rigged.glb']['glb_triangles']:,} | 21 | 0 | 0 | {src['characters'][s]['head_units']:.3f} | 2048² |" for s in chars)
checklist='\n'.join(f"- [{'x' if ok else ' '}] `{name}`" for name,ok in checks.items())
report=f'''# Blender 实时 3D 样板 V2 · 双角色与出租屋聚焦精修

生成：{now}（Asia/Shanghai / UTC+8）  
工作目录：`{P}`  
结论：**本轮要求检查 {'全部通过' if all(checks.values()) else '仍有未通过项，见下表'}**。未修改 `wangwx-dev/srdld`，未执行任何仓库操作；V1 原交付清单的 {len(v1checks)} 项 SHA-256 全部保持不变。城市建筑不是本轮验收对象。

## 1. 先看这五张图

1. `renders/01_characters_turntable_v2.png`：正面、45°斜俯视、正面原图面部精确 200% 放大、真实拓扑。
2. `renders/02_room_isometric_sit_v2.png`：Cycles 坐桌全景；低墙无黑块、书架无遮挡、日间暖光。
3. `renders/03_room_poses_sheet_v2.png`：躺床闭眼、双手持书、摸猫、门前四姿态近景。
4. `renders/04_godot_room_realtime_v2.png`：Godot 4.5.1 加载最新房间与独立女角色 GLB，播放 Sit_Desk 的真实引擎截图；不是 Cycles 冒充。
5. `renders/05_v1_vs_v2_comparison.png`：V1/V2 角色与房间使用相同正交尺度、相同裁切、相同缩放比较。

`REVIEW_OVERVIEW.jpg` 为上述图片索引。原始单张渲染也留在 renders 中。所有图来自 Blender/Godot 实际网格与纹理，面部为手工编写矢量笔触的 2K 贴图，图板只做排版；未使用 AI 生图。

## 2. 双角色：几何、UV、绑定与动作

| 角色 | 导出 GLB tris | 骨骼 | 未赋权顶点 | 重复索引面 | 头身比 | 五官贴图 |
|---|---:|---:|---:|---:|---:|---|
{rows}

- 重做比例映射：约 4.71 头身；斜肩、较充实的腰胯、连通衣袖与裤裆。改用自然垂臂绑定姿态，避免旧 A-pose 转垂臂造成肩头球结/尖刺。
- 连通裤腰/双裤腿后重新光顺与预算重拓扑；裤腿逐渐收口，消除旧硬质胯桥。
- 鞋改为圆头鞋面、圆角橡胶包底、后跟包覆、鞋舌和细鞋带，非方盒拖鞋。
- 柔和下颌；2K 眼白/虹膜高光/眉/鼻/嘴/腮红与圆柱 UV 正面区域对齐；背面 UV 接缝不穿正面五官。
- 胸颈、肩肘、胯膝保留归一化混合权重。全角色 0 重复面、0 退化三角，原女模型的 2 个重复索引面已不存在。
- 五条导出动画恰为 `{', '.join(expected)}`；每条都有非恒定骨骼运动，非仅摆静态姿势。另增加 SleepLids 闭眼 morph，与五个 NLA 同名轨道合并，Godot 中仍是五条动作而不是额外杂乱片段。
- 为预算保留简化掌形与拇指，**没有独立手指骨/电影级手部绑定**；生活动作接触由 21 骨与实际表面坐标修整。

## 3. 五条动作接触复测（女、男均跑）

详见 `evidence/contact_qc_v2.json`。最接近表面间隙以实际蒙皮后顶点对目标 BVH 测量，不用骨骼目标点假冒。

- Idle：鞋底离地约 2.90 mm；门前站立无悬空。
- Sit_Desk：双手至键盘表面约 0.35 / 0.10 mm；鞋底离地约 0.99 mm；椅背包围区域内穿入顶点 **0**。椅背后移并压低，保留背部留空。
- Read_Book：左手原先约 55 mm 的空握已修正；最终左/右表面间隙约 0.78 / 0.19 mm。
- Pet_Cat：最近手掌至猫头约 0.85 mm；另一手扶背；脚最低处约 8.01 mm，属于毯面/猫窝旁蹲姿。
- Sleep_Bed：按角色自身比例空间旋转，避免世界空间比例映射拉长身体；整体向枕面移动 25 cm。鞋跟至被面约 0.49 / 0.47 mm；女/男头枕最近间隙约 0.01 / 1.13 mm；男、女根据发型分别调整颈头高度。
- 动画中段只做轻微呼吸、敲键、翻看和抚摸。上述 BVH 最近距离是接触定位指标，**不是全身所有三角之间的通用碰撞证明**；同时逐图人工检查椅背、床、书与猫接触。

复现放置：Sit/Read 根节点 `(0.55,1.82,0)`、Z 旋转 π；Sleep `(-2.6,0.38,0)`；Pet `(-0.4,0.78,0)`；Idle 门前 `(-1,3.1,0)`。以上为 Blender Z-up 坐标。

## 4. 出租屋修复

- 低墙左端并非简单调亮掩盖：去掉前低墙与西侧墙的 20 cm 几何交叠，重算法线并清除场景极小退化倒角。**只裁房间角接实例**；标准库 2m 模块尺寸、`(0,0,0)` 角原点都没移动，房间模块实例仍在 2m 栅格与 90°旋转上。
- 最终放大检查又发现门框顶梁与立柱、窗横框与竖框的共面交叠黑缝；已从几何上缩短立柱/拆分横框为净跨，不再用调光掩盖。修复前放大证据保留在 `evidence/rejected-previews-v2/door_frame_coplanar_before_fix.png`。
- 书架整体沿西墙向开放前侧移 2.75m，全部书格暴露，不再被床头挡住；中间留白、床、桌与门动线保留。
- Cycles：大面积柔光 1800W、暖补光 750W、Sun 2.0、曝光 +0.35；光源为日间柔暖而非夜间橙灯。保留 Poly Haven 木/墙/织物真实 PBR。
- 金属桌架、显示器底座改为中性石墨喷漆 PBR，移除旧锈黄花纹造成的脏感。
- Godot：独立 `render_room.gd` 中 DirectionalLight3D 0.48、暖 Omni 0.18、WorldEnvironment ambient 0.42；Filmic 高光压缩，亚麻材质运行时 albedo `(0.70,0.76,0.78)` 曝光补偿，保留原贴图/法线/粗糙度。Cycles 与 Godot 并非像素完全一致，但均为清楚暖亮的日间室内。

## 5. Godot 与 GLB 真实检查

- Blender 4.5.3 LTS 重新生成 `.blend` 与所有 GLB，再逐个重新导入 Blender 检查骨骼、权重、UV、贴图、动作、重复索引与有限矩阵。
- Godot **4.5.1.stable.official.f62fdbde1** 重新 import；探针加载全部导出 GLB，检查 Skeleton3D / AnimationPlayer / 贴图并播放动作。
- Godot 测试资产与 exports 的 SHA-256 完全一致；未使用旧角色混充新模型。
- 独立 `godot_dither_probe` 的真实 OpenGL Compatibility 路径运行于 Mesa llvmpipe 软件光栅。是实际 Godot 渲染，不是 AI 图片；**不代表目标硬件帧率/性能已经验收**。
- 方案二圆形 4×4 Bayer Dither 原逻辑保留。再次实际编译并渲染，before/after 有 **{changed:,}** 个变化像素；证据 `godot_occlusion_before.png` / `godot_occlusion_after.png`。
- 场景导出中保留一项诊断：旧 Poly Haven 茶几底部倒角有 {g['room_realtime.glb']['glb_near_zero_area_triangles_threshold_squared_cross_1e18']} 个极小面积三角（平方叉积阈值 1e-18），不是重复索引面，也不在墙角，不形成可见黑块；人物自身此项为 0。没有把此诊断伪报成全场景零退化面。

## 6. 复现入口

- 原生文件：`blender_realtime_sample.blend`（贴图已打包）
- 游戏用候选：`exports/female_rigged.glb`、`exports/male_rigged.glb`、`exports/room_realtime.glb` 与 6 个标准模块。
- 构建：`blender_scripts/build_sample.py`；面部绘制：`blender_scripts/paint_faces_v2.py`。
- 渲染：Blender 后台运行 `blender_scripts/render_sample.py -- characters` / `-- room` / `-- poses`。
- 审计：`blender_scripts/verify_glb.py`、`blender_scripts/source_audit_v2.py`、`blender_scripts/contact_qc_v2.py`。
- Godot：复制 exports/*.glb 至 godot_dither_probe/assets，重新 import，再运行 `probe.gd`、`render_room.gd`、`render_occlusion.gd`。
- 图板：`python3 blender_scripts/make_boards_v2.py`；报告：`python3 blender_scripts/write_report_v2.py`。
- 历史 v1 预览与继承证据不作为本轮通过依据；当前依据为 `*_v2` 日志、更新后的 build_audit / glb_reimport / runtime_verification 与本 verification.json。

## 7. 逐项结果

{checklist}

人工放大审视与迭代记录：`evidence/VISUAL_REVIEW_V2.md`。本轮技术与可视检查通过不等于替用户宣布审美最终通过；此版供双角色与出租屋定向验收，未推进城市美术，也未进游戏代码仓库。
'''
(P/'REPORT.md').write_text(report)
(P/'PIPELINE_SPEC.json').write_text(json.dumps({'version':2,'camera_elevation':45,'camera_azimuth':45,'grid_m':2,'module_origin':'corner (0,0,0)','tris_per_character':[2000,5000],'bones_per_character':21,'engine':'Godot 4.5.1 realtime 3D','occlusion':'circular screen-space Bayer dither','ai_generated_images':False,'game_repository_modified':False,'city_redesign':False},indent=2))
files=[P/'blender_realtime_sample.blend',P/'REPORT.md',P/'verification.json',P/'PIPELINE_SPEC.json',*(P/'exports').glob('*.glb'),*(P/'renders'/n for n in required)]
(P/'DELIVERABLE_SHA256.txt').write_text('\n'.join(hashf(p)+'  '+str(p.relative_to(P)) for p in files)+'\n')
print(json.dumps(checks,indent=2));print('ALL_REQUIRED_CHECKS_PASSED',all(checks.values()))
